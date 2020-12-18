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
    in_use_channels: u2048, // Hear me out...
    max_channels: u16,

    const Self = @This();

    pub fn init(rx_memory: []u8, tx_memory: []u8) Connection {
        return Connection{
            .connector = Connector {
                .rx_buffer = WireBuffer.init(rx_memory[0..]),
                .tx_buffer = WireBuffer.init(tx_memory[0..]),
                .channel = 0,
            },
            .in_use_channels = 1,
            .max_channels = 32
        };
    }

    pub fn connect(self: *Self, allocator: *mem.Allocator, host: ?[]u8, port: ?u16) !void {
        // callbacks.init();

        const file = try net.tcpConnectToHost(allocator, host orelse "127.0.0.1", port orelse 5672);
        const n = try file.write("AMQP\x00\x00\x09\x01");

        self.connector.file = file;
        self.connector.connection = self;

        var start_response = try proto.Connection.awaitStart(&self.connector);

        var tune_response = try proto.Connection.awaitTune(&self.connector);

        var open_repsonse = try proto.Connection.openSync(&self.connector, "/");
    }

    pub fn deinit(self: *Self) void {
        self.file.close();
    }

    pub fn channel(self: *Self) !Channel {
        const next_available_channel = try self.next_channel();
        var ch = Channel.init(next_available_channel, self);

        var open_ok = try proto.Channel.openSync(&ch.connector);

        return ch;
    }

    fn next_channel(self: *Self) !u16 {
        var i: u16 = 1;
        while (i < self.max_channels and i < @bitSizeOf(u2048)) : ( i += 1 ) {
            const bit: u2048 = 1;
            const shift: u11 = @intCast(u11, i);
            if (self.in_use_channels & (bit << shift) == 0) {
                self.in_use_channels |= (bit << shift);
                return i;
            }
        }

        return error.NoFreeChannel;
    }

    pub fn free_channel(self: *Self, channel_id: u16) void {
        if (channel_id >= @bitSizeOf(u2048)) return; // Look it's late okay...
        const bit: u2048 = 1;
        self.in_use_channels &= ~(bit << @intCast(u11, channel_id));
        if (std.builtin.mode == .Debug) std.debug.warn("Freed channel {}, in_use_channels: {}\n", .{channel_id, @popCount(u2048, self.in_use_channels)});
    }
};