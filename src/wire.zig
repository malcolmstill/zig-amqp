const std = @import("std");
const net = std.net;
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const builtin = std.builtin;
const proto = @import("protocol.zig");
const init = @import("init.zig");

pub fn open(allocator: *mem.Allocator, host: ?[]u8, port: ?u16) !Wire {
    init.init();

    const file = try net.tcpConnectToHost(allocator, host orelse "127.0.0.1", port orelse 5672);
    const n = try file.write("AMQP\x00\x00\x09\x01");

    var conn = Wire {
        .file = file,
    };
    // We asynchronously process incoming messages (calling callbacks )
    var received_response = false;
    while (!received_response) {
        const expecting: ClassMethod = .{ .class = proto.CONNECTION_CLASS, .method = proto.Connection.START_METHOD };
        received_response = try conn.dispatch(allocator, expecting);
    }

    return conn;
}

pub const Wire = struct {
    file: fs.File,
    rx_buffer: [4096]u8 = undefined,
    tx_buffer: [4096]u8 = undefined,
    read_head: usize = 0,
    write_head: usize = 0,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.file.close();
    }

    // dispatch reads from our socket and dispatches methods in response
    // Where dispatch is invoked in initialising a request, we pass in an expected_response
    // ClassMethod that specifies what (synchronous) response we are expecting. If this value
    // is supplied and we receive an incorrect (synchronous) method we error, otherwise we
    // dispatch and return true. In the case
    // (expected_response supplied), if we receive an asynchronous response we dispatch it
    // but return true.
    pub fn dispatch(self: *Self, allocator: *mem.Allocator, expected_response: ?ClassMethod) !bool {
        self.read_head = 0;
        const n = try os.read(self.file.handle, self.rx_buffer[0..]);

        if (n < @sizeOf(FrameHeader)) return error.HeaderReadFailed;
        const header = @ptrCast(*FrameHeader, &self.rx_buffer[self.read_head]);
        self.read_head += @sizeOf(FrameHeader);
        const size = byteOrder(u32, header.size);

        switch (header.@"type") {
            .Method => {
                const method_header = @ptrCast(*MethodHeader, &self.rx_buffer[self.read_head]);
                const class = byteOrder(u16, method_header.class);
                const method = byteOrder(u16, method_header.method);
                self.read_head += @sizeOf(MethodHeader);

                if (expected_response) |expected| {
                    // TODO: ignore asynchronous
                    const is_synchronous = try proto.isSynchronous(class, method);
                    
                    if (is_synchronous) {
                        if (class != expected.class) return error.UnexpectedResponseClass;
                        if (method != expected.method) return error.UnexpectedResponseClass;
                    }
                    try proto.dispatchCallback(self, class, method);
                    return true;
                } else {
                    try proto.dispatchCallback(self, class, method);
                    return false;
                }
            },
            .Heartbeat => {
                std.debug.warn("Got heartbeat\n", .{});
                return false;
            },
            else => {
                return false;
            },
        }
    }

    pub fn readU8(self: *Self) u8 {
        const r = @ptrCast(u8, self.rx_buffer[self.read_head]);
        self.read_head += 1;
        return r;
    }

    pub fn readU16(self: *Self) u16 {
        const r = @ptrCast(*u16, @alignCast(@alignOf(u16), &self.rx_buffer[self.read_head]));
        self.read_head += 2;
        return byteOrder(u16, r.*);
    }

    pub fn readU32(self: *Self) u32 {
        const r = @ptrCast(*u32, @alignCast(@alignOf(u32), &self.rx_buffer[self.read_head]));
        self.read_head += 4;
        return byteOrder(u32, r.*);
    }

    pub fn readU64(self: *Self) u64 {
        const r = @ptrCast(*u64, @alignCast(@alignOf(u64), &self.rx_buffer[self.read_head]));
        self.read_head += 8;
        return byteOrder(u64, r.*);
    }

    pub fn readBool(self: *Self) bool {
        return false;
    }

    pub fn readArrayU8(self: *Self) []u8 {
        const array = self.rx_buffer[self.read_head..self.read_head+128];
        return array;
    }

    pub fn readArray128U8(self: *Self) []u8 {
        const array = self.rx_buffer[self.read_head..self.read_head+128];
        return array;
    }

    pub fn readOptionalArray128U8(self: *Self) ?[]u8 {
        const array = self.rx_buffer[self.read_head..self.read_head+128];
        return array;
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

const ClassMethod = struct {
    class: u16 = 0,
    method: u16 = 0,
};