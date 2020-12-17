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
const ClassMethod = @import("connector.zig").ClassMethod;
const Channel = @import("channel.zig").Channel;

pub const Connection = struct {
    connector: Connector,
    in_use_channels: u16,
    max_channels: u16,

    const Self = @This();

    pub fn init(rx_memory: []u8, tx_memory: []u8, file: fs.File) Connection {
        return Connection{
            .connector = Connector {
                .file = file,
                .rx_buffer = WireBuffer.init(rx_memory[0..]),
                .tx_buffer = WireBuffer.init(tx_memory[0..]),
                .channel = 0,
            },
            .in_use_channels = 1,
            .max_channels = 32
        };
    }

    pub fn open(rx_memory: []u8, tx_memory: []u8, allocator: *mem.Allocator, host: ?[]u8, port: ?u16) !Connection {
        callbacks.init();

        const file = try net.tcpConnectToHost(allocator, host orelse "127.0.0.1", port orelse 5672);
        const n = try file.write("AMQP\x00\x00\x09\x01");

        var connection: Connection = Connection.init(rx_memory, tx_memory, file);

        // TODO: I think we want something like an await_start_ok()
        // We asynchronously process incoming messages (calling callbacks )
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = proto.CONNECTION_CLASS, .method = proto.Connection.START_METHOD };
            received_response = try connection.connector.dispatch(expecting);
        }

        // Await tune
        received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = proto.CONNECTION_CLASS, .method = proto.Connection.TUNE_METHOD };
            received_response = try connection.connector.dispatch(expecting);
        }

        try proto.Connection.open_sync(&connection.connector, "/");

        return connection;
    }

    pub fn deinit(self: *Self) void {
        self.file.close();
    }

    pub fn channel(self: *Self) !Channel {
        const next_available_channel = try self.next_channel();
        var ch = Channel.init(next_available_channel, self);

        try proto.Channel.open_sync(&ch.connector);

        return ch;
    }

    fn next_channel(self: *Self) !u16 {
        var i: u4 = 0;
        while (i < self.max_channels) : ( i += 1 ) {
            const bit: u16 = 1;
            if (self.in_use_channels & (bit << i) == 0) {
                self.in_use_channels |= (bit << i);
                return i;
            }
        }

        return error.NoFreeChannel;
    }
};