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

pub const Conn = struct {
    file: fs.File,
    rx_memory: [4096]u8 = undefined,
    tx_memory: [4096]u8 = undefined,
    rx_buffer: WireBuffer = undefined,
    tx_buffer: WireBuffer = undefined,

    const Self = @This();

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
            received_response = try conn.dispatch(expecting);
        }

        // Await tune
        received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = proto.CONNECTION_CLASS, .method = proto.Connection.TUNE_METHOD };
            received_response = try conn.dispatch(expecting);
            if (received_response) std.debug.warn("Received tune\n", .{});
        }

        var connection: proto.Connection = proto.Connection { .conn = &conn };
        try connection.open_sync("/");

        return conn;
    }

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
    pub fn dispatch(self: *Self, expected_response: ?ClassMethod) !bool {
        const n = try os.read(self.file.handle, self.rx_memory[0..]);
        self.rx_buffer = WireBuffer.init(self.rx_memory[0..n]);
        self.tx_buffer = WireBuffer.init(self.tx_memory[0..]);

        // 1. Attempt to read a frame header
        const header = try self.rx_buffer.readFrameHeader();

        switch (header.@"type") {
            .Method => {
                // 2a. The frame header says this is a method, attempt to read
                // the method header
                const method_header = try self.rx_buffer.readMethodHeader();
                const class = method_header.class;
                const method = method_header.method;

                var sync_resp_ok = false;
                
                // 3a. If this is a synchronous call, we expect expected_response to be 
                // non-null and to provide the expected class and method of the response
                // that we're waiting on. That class and method is checked for being
                // a synchronous response and then we compare the class / method from the
                // header with expected_response and error if they don't match.
                if (expected_response) |expected| {
                    const is_synchronous = try proto.isSynchronous(class, method);
                    
                    if (is_synchronous) {
                        if (class == expected.class and method == expected.method) {
                            sync_resp_ok = true;
                        } else {
                            sync_resp_ok = false;
                        }
                    } else {
                        sync_resp_ok = true;
                    }
                }

                // 4a. Finally dispatch the class / method
                try proto.dispatchCallback(self, class, method);
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

pub const ClassMethod = struct {
    class: u16 = 0,
    method: u16 = 0,
};