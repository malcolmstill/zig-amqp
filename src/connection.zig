const std = @import("std");
const net = std.net;
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const builtin = std.builtin;

pub fn open(allocator: *mem.Allocator, host: ?[]u8, port: ?u16) !Connection {
    const file = try net.tcpConnectToHost(allocator, host orelse "127.0.0.1", port orelse 5672);
    const n = try file.write("AMQP\x00\x00\x09\x01");

    var conn = Connection {
        .file = file,
    };
    // We asynchronously process incoming messages (calling callbacks ) 
    while (true) {
        const message = try conn.dispatch(allocator, null);
    }

    return conn;
}

pub const Connection = struct {
    file: fs.File,
    rx_buffer: [4096]u8 = undefined,
    tx_buffer: [4096]u8 = undefined,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.file.close();
    }

    pub fn dispatch(self: *Self, allocator: *mem.Allocator, response: ?struct{ class: u16, method: u16 }) !void {
        const n = try os.read(self.file.handle, self.rx_buffer[0..]);

        if (n < @sizeOf(FrameHeader)) return error.HeaderReadFailed;
        const header = @ptrCast(*FrameHeader, &self.rx_buffer[0]);
        const size = byteOrder(u32, header.size);

        switch (header.@"type") {
            .Method => {
                const method = @ptrCast(*MethodHeader, &self.rx_buffer[@sizeOf(FrameHeader)]);
                std.debug.warn("Got method: {}.{}\n", .{ byteOrder(u16, method.class), byteOrder(u16, method.method)});
            },
            else => {},
        }
    }
};

// AMQP uses network byte order, i.e. big endian.
// Reorder on little endian systems.
fn byteOrder(comptime T: type, value: T) T {
    return switch (builtin.endian) {
        .Big => value,
        .Little => @byteSwap(T, value),
    };
}

// const Frame = packed struct {
//     header: FrameHeader = undefined,
//     class: u16 = 0,
//     method: u16 = 0,
// };

const FrameHeader = packed struct {
    @"type": FrameType = .Method,
    channel: u16 = 0,
    size: u32 = 0,
};

const FrameType = enum(u8) {
    Method = 1,
    Header,
    Body,
    Heartbeat,
};

const MethodHeader = packed struct {
    class: u16 = 0,
    method: u16 = 0,
};