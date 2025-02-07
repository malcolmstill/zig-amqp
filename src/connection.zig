const std = @import("std");
const net = std.net;
const mem = std.mem;
const posix = std.posix;
const builtin = std.builtin;
const proto = @import("protocol.zig");
const WireBuffer = @import("wire.zig").WireBuffer;
const Connector = @import("connector.zig").Connector;
const Channel = @import("channel.zig").Channel;
const Table = @import("table.zig").Table;

pub const Connection = struct {
    connector: Connector,
    in_use_channels: u2048, // Hear me out...
    max_channels: u16,

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

    pub fn connect(connection: *Connection, address: net.Address) !void {
        const file = try net.tcpConnectToAddress(address);
        _ = try file.write("AMQP\x00\x00\x09\x01");

        connection.connector.file = file;
        connection.connector.connection = connection;

        var start = try proto.Connection.awaitStart(&connection.connector);
        const remote_host = start.server_properties.lookup([]u8, "cluster_name");
        std.log.debug("Connected to {any} AMQP server (version {any}.{any})\nmechanisms: {any}\nlocale: {any}\n", .{
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
        try proto.Connection.startOkAsync(&connection.connector, &client_properties, "PLAIN", "\x00guest\x00guest", "en_US");

        const tune = try proto.Connection.awaitTune(&connection.connector);
        connection.max_channels = tune.channel_max;
        try proto.Connection.tuneOkAsync(&connection.connector, @bitSizeOf(u2048) - 1, tune.frame_max, tune.heartbeat);

        _ = try proto.Connection.openSync(&connection.connector, "/");
    }

    pub fn deinit(connection: *Connection) void {
        connection.connector.file.close();
    }

    pub fn channel(connection: *Connection) !Channel {
        const next_available_channel = try connection.nextChannel();
        var ch = Channel.init(next_available_channel, connection);

        _ = try proto.Channel.openSync(&ch.connector);

        return ch;
    }

    fn nextChannel(connection: *Connection) !u16 {
        var i: u16 = 1;
        while (i < connection.max_channels and i < @bitSizeOf(u2048)) : (i += 1) {
            const bit: u2048 = 1;
            const shift: u11 = @intCast(i);
            if (connection.in_use_channels & (bit << shift) == 0) {
                connection.in_use_channels |= (bit << shift);
                return i;
            }
        }

        return error.NoFreeChannel;
    }

    pub fn freeChannel(connection: *Connection, channel_id: u16) void {
        if (channel_id >= @bitSizeOf(u2048)) return; // Look it's late okay...
        const bit: u2048 = 1;
        connection.in_use_channels &= ~(bit << @intCast(channel_id));
        if (std.options.log_level == .debug) std.debug.print("Freed channel {any}, in_use_channels: {any}\n", .{ channel_id, @popCount(connection.in_use_channels) });
    }
};

const testing = std.testing;

test "read / write / shift volatility" {
    var server_rx_memory: [128]u8 = [_]u8{0} ** 128;
    var server_tx_memory: [128]u8 = [_]u8{0} ** 128;
    var client_rx_memory: [128]u8 = [_]u8{0} ** 128;
    var client_tx_memory: [128]u8 = [_]u8{0} ** 128;

    const server_rx_buf = WireBuffer.init(server_rx_memory[0..]);
    const server_tx_buf = WireBuffer.init(server_tx_memory[0..]);

    _ = WireBuffer.init(client_rx_memory[0..]);
    _ = WireBuffer.init(client_tx_memory[0..]);

    const f = try posix.pipe();
    defer posix.close(f[0]);
    defer posix.close(f[1]);

    var server_connector = Connector{
        .file = net.Stream{
            .handle = f[0],
        },
        .rx_buffer = server_rx_buf,
        .tx_buffer = server_tx_buf,
        .channel = 0,
    };

    var client_connector = Connector{
        .file = net.Stream{
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
    const block = try server_connector.awaitMethod(proto.Connection.Blocked);
    try testing.expect(mem.eql(u8, block.reason, "hello"));
    const block2 = try proto.Connection.awaitBlocked(&server_connector); // alternative form of await
    try testing.expect(mem.eql(u8, block2.reason, "world"));

    // Due to volatility, block.reason may not remain "hello"
    // 1. Having called awaitBlocked a second time, we're actually still good
    //    as before messages are still in their original location in the buffer:
    try testing.expect(mem.eql(u8, block.reason, "hello"));
    // 2. If another message is written and we copy it to the front of the buffer (shift)
    //    and then await again, we find that block.reason is now "overw" instead of "hello"
    try proto.Connection.blockedAsync(&client_connector, "overwritten");
    server_connector.rx_buffer.shift();
    _ = try server_connector.awaitMethod(proto.Connection.Blocked);
    try testing.expect(mem.eql(u8, block.reason, "overw"));
}
