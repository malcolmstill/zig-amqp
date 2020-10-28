const std = @import("std");
const net = std.net;
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const builtin = std.builtin;
const proto = @import("protocol.zig");
const init = @import("init.zig");
const wire = @import("wire.zig");
const WireBuffer = @import("wire.zig").WireBuffer;

pub fn open(allocator: *mem.Allocator, host: ?[]u8, port: ?u16) !Conn {
    init.init();

    const file = try net.tcpConnectToHost(allocator, host orelse "127.0.0.1", port orelse 5672);
    const n = try file.write("AMQP\x00\x00\x09\x01");

    var conn = Conn {
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

pub const Conn = struct {
    file: fs.File,
    rx_buffer: [4096]u8 = undefined,
    tx_buffer: [4096]u8 = undefined,

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
        const n = try os.read(self.file.handle, self.rx_buffer[0..]);
        var buf = WireBuffer.init(self.rx_buffer[0..n]);

        const header = try buf.readFrameHeader();

        switch (header.@"type") {
            .Method => {
                const method_header = try buf.readMethodHeader();
                const class = method_header.class;
                const method = method_header.method;

                var sync_resp_ok = false;
                
                if (expected_response) |expected| {
                    const is_synchronous = try proto.isSynchronous(class, method);
                    
                    if (is_synchronous) {
                        if (class != expected.class) return error.UnexpectedResponseClass;
                        if (method != expected.method) return error.UnexpectedResponseClass;
                    }
                    sync_resp_ok = true;
                }

                try proto.dispatchCallback(&buf, class, method);
                return sync_resp_ok;
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
};

const ClassMethod = struct {
    class: u16 = 0,
    method: u16 = 0,
};