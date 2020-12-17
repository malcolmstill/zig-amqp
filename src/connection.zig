const std = @import("std");
const net = std.net;
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const builtin = std.builtin;
const proto = @import("protocol.zig");
const callbacks = @import("init.zig");
const wire = @import("wire.zig");
const WireBuffer = @import("wire.zig").WireBuffer;
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

    // TODO: This should return Connection instead of Conn
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
        while (i < self.max_channels) : ( i += 1) {
            const bit: u16 = 1;
            if (self.in_use_channels & (bit << i) == 0) {
                self.in_use_channels |= (bit << i);
                return i;
            }
        }

        return error.NoFreeChannel;
    }
};

// TODO: think up a better name for this
pub const Connector = struct {
    file: fs.File,
    rx_buffer: WireBuffer = undefined,
    tx_buffer: WireBuffer = undefined,
    channel: u16,

    const Self = @This();

    // dispatch reads from our socket and dispatches methods in response
    // Where dispatch is invoked in initialising a request, we pass in an expected_response
    // ClassMethod that specifies what (synchronous) response we are expecting. If this value
    // is supplied and we receive an incorrect (synchronous) method we error, otherwise we
    // dispatch and return true. In the case
    // (expected_response supplied), if we receive an asynchronous response we dispatch it
    // but return true.
    pub fn dispatch(self: *Self, expected_response: ?ClassMethod) !bool {
        const n = try os.read(self.file.handle, self.rx_buffer.mem[0..]);
        self.rx_buffer.reset();
        self.tx_buffer.reset();

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
                        // if (class != expected.class) return error.UnexpectedResponseClass;
                        // if (method != expected.method) return error.UnexpectedResponseClass;
                        if (class == expected.class and method == expected.method) {
                            sync_resp_ok = true;
                        } else {
                            // TODO: we might receive an unexpecte close with a CHANNEL_ERROR
                            //       we should signal a separate error perhaps
                            // sync_resp_ok = false;
                            return error.UnexpectedSync;
                        }
                    } else {
                        sync_resp_ok = true;
                    }
                }

                // 4a. Finally dispatch the class / method
                // const connection: *proto.Connection = @fieldParentPtr(proto.Connection, "conn", self);
                try proto.dispatchCallback(self, class, method);
                return sync_resp_ok;
            },
            .Heartbeat => {
                if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
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
