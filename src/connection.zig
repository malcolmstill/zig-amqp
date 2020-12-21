const std = @import("std");
const net = std.net;
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const builtin = std.builtin;
const proto = @import("protocol.zig");
const callbacks = @import("init.zig");
const WireBuffer = @import("wire.zig").WireBuffer;
const Connector = @import("connector.zig").Connector;
const Channel = @import("channel.zig").Channel;
const Table = @import("table.zig").Table;

pub const Connection = struct {
    connector: Connector,
    in_use_channels: u2048, // Hear me out...
    max_channels: u16,

    const Self = @This();

    pub fn init(rx_memory: []u8, tx_memory: []u8) Connection {
        return Connection{
            .connector = Connector{
                .rx_buffer = WireBuffer.init(rx_memory[0..]),
                .tx_buffer = WireBuffer.init(tx_memory[0..]),
                .channel = 0,
            },
            .in_use_channels = 1,
            .max_channels = 32,
        };
    }

    pub fn connect(self: *Self, address: net.Address) !void {
        const file = try net.tcpConnectToAddress(address);
        const n = try file.write("AMQP\x00\x00\x09\x01");

        self.connector.file = file;
        self.connector.connection = self;

        var start = try proto.Connection.awaitStart(&self.connector);
        const remote_host = start.server_properties.lookup([]u8, "cluster_name");
        std.log.debug("Connected to {} AMQP server (version {}.{})\nmechanisms: {}\nlocale: {}\n", .{
            remote_host,
            start.version_major,
            start.version_minor,
            start.mechanisms,
            start.locales,
        });

        var props_buffer: [1024]u8 = undefined;
        var client_properties: Table = Table.init(props_buffer[0..]);

        client_properties.insertLongString("product", "Zig AMQP Library");
        client_properties.insertLongString("platform", "Zig 0.7.0");

        // TODO: it's annoying having 3 lines for a single initialisation
        // UPDATE: thoughts. We can at least get rid of the caps_wb if Table.init
        //         does its own WireBuffer init from the backing buffer.
        //         Also, perhaps we can offer a raw slice backed Table.init and,
        //         say, a Table.initAllocator() that takes an allocator instead.
        //         This gives users the freedom to decide how they want to deal
        //         with memory.
        var caps_buf: [1024]u8 = undefined;
        var capabilities: Table = Table.init(caps_buf[0..]);

        capabilities.insertBool("authentication_failure_close", true);
        capabilities.insertBool("basic.nack", true);
        capabilities.insertBool("connection.blocked", true);
        capabilities.insertBool("consumer_cancel_notify", true);
        capabilities.insertBool("publisher_confirms", true);
        client_properties.insertTable("capabilities", &capabilities);

        client_properties.insertLongString("information", "See https://github.com/malcolmstill/zig-amqp");
        client_properties.insertLongString("version", "0.0.1");

        // TODO: We want to be able to call start_ok_resp as a function
        //       rather than having to deal with buffers.
        // UPDATE: the above TODO is what we now have, but we require extra
        //         buffers, and how do we size them. It would be nice to
        //         avoid allocations.
        try proto.Connection.startOkAsync(&self.connector, &client_properties, "PLAIN", "\x00guest\x00guest", "en_US");

        var tune = try proto.Connection.awaitTune(&self.connector);
        self.max_channels = tune.channel_max;
        try proto.Connection.tuneOkAsync(&self.connector, @bitSizeOf(u2048) - 1, tune.frame_max, tune.heartbeat);

        var open_repsonse = try proto.Connection.openSync(&self.connector, "/");
    }

    pub fn deinit(self: *Self) void {
        self.file.close();
    }

    pub fn channel(self: *Self) !Channel {
        const next_available_channel = try self.nextChannel();
        var ch = Channel.init(next_available_channel, self);

        _ = try proto.Channel.openSync(&ch.connector);

        return ch;
    }

    fn nextChannel(self: *Self) !u16 {
        var i: u16 = 1;
        while (i < self.max_channels and i < @bitSizeOf(u2048)) : (i += 1) {
            const bit: u2048 = 1;
            const shift: u11 = @intCast(u11, i);
            if (self.in_use_channels & (bit << shift) == 0) {
                self.in_use_channels |= (bit << shift);
                return i;
            }
        }

        return error.NoFreeChannel;
    }

    pub fn freeChannel(self: *Self, channel_id: u16) void {
        if (channel_id >= @bitSizeOf(u2048)) return; // Look it's late okay...
        const bit: u2048 = 1;
        self.in_use_channels &= ~(bit << @intCast(u11, channel_id));
        if (std.builtin.mode == .Debug) std.debug.warn("Freed channel {}, in_use_channels: {}\n", .{ channel_id, @popCount(u2048, self.in_use_channels) });
    }
};

const testing = std.testing;

test "read / write / shift volatility" {
    var server_rx_memory: [128]u8 = [_]u8{0} ** 128;
    var server_tx_memory: [128]u8 = [_]u8{0} ** 128;
    var client_rx_memory: [128]u8 = [_]u8{0} ** 128;
    var client_tx_memory: [128]u8 = [_]u8{0} ** 128;

    var server_rx_buf = WireBuffer.init(server_rx_memory[0..]);
    var server_tx_buf = WireBuffer.init(server_tx_memory[0..]);

    var client_rx_buf = WireBuffer.init(client_rx_memory[0..]);
    var client_tx_buf = WireBuffer.init(client_tx_memory[0..]);

    const f = try os.pipe();
    defer os.close(f[0]);
    defer os.close(f[1]);

    var server_connector = Connector{
        .file = fs.File{
            .handle = f[0],
        },
        .rx_buffer = server_rx_buf,
        .tx_buffer = server_tx_buf,
        .channel = 0,
    };

    var client_connector = Connector{
        .file = fs.File{
            .handle = f[1],
        },
        .rx_buffer = server_rx_buf,
        .tx_buffer = server_tx_buf,
        .channel = 0,
    };

    try proto.Connection.blockedAsync(&client_connector, "hello");
    try proto.Connection.blockedAsync(&client_connector, "world");

    // volatile values should be valid until at least the next call that
    // modifies the underlying buffers
    var block = try server_connector.awaitMethod(proto.Connection.Blocked);
    testing.expect(mem.eql(u8, block.reason, "hello"));
    var block2 = try proto.Connection.awaitBlocked(&server_connector); // alternative form of await
    testing.expect(mem.eql(u8, block2.reason, "world"));

    // Due to volatility, block.reason may not remain "hello"
    // 1. Having called awaitBlocked a second time, we're actually still good
    //    as before messages are still in their original location in the buffer:
    testing.expect(mem.eql(u8, block.reason, "hello"));
    // 2. If another message is written and we copy it to the front of the buffer (shift)
    //    and then await again, we find that block.reason is now "overw" instead of "hello"
    try proto.Connection.blockedAsync(&client_connector, "overwritten");
    server_connector.rx_buffer.shift();
    var block3 = try server_connector.awaitMethod(proto.Connection.Blocked);
    testing.expect(mem.eql(u8, block.reason, "overw"));
}
