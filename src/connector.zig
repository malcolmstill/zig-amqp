const std = @import("std");
const os = std.os;
const fs = std.fs;
const proto = @import("protocol.zig");
const WireBuffer = @import("wire.zig").WireBuffer;
const Connection = @import("connection.zig").Connection;

// TODO: think up a better name for this
pub const Connector = struct {
    file: fs.File = undefined,
    // TODO: we're going to run into trouble real fast if we reallocate the buffers
    //       and we have a bunch of copies of Connector everywhere. I think we just
    //       need to store a pointer to the Connection
    rx_buffer: WireBuffer = undefined,
    tx_buffer: WireBuffer = undefined,
    connection: *Connection = undefined,
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
        // If we don't have any data (and we're dispatching so we expect data)
        // block on read
        // I don't think this is right, if we have a partial read, we'll never
        // read more data
        if (!self.rx_buffer.frameReady()) {
            const n = try os.read(self.file.handle, self.rx_buffer.remaining());
            self.rx_buffer.incrementEnd(n);
        }
        self.rx_buffer.reset();
        self.tx_buffer.reset();

        // self.rx_buffer.printSpan();
        defer self.rx_buffer.shift();

        while (self.rx_buffer.head < self.rx_buffer.end) : ( i += 1 ) {
            // 1. Attempt to read a frame header
            const header = try self.rx_buffer.readFrameHeader();

            switch (header.@"type") {
                // TODO: if we have a failure here, we probably still want to
                //       copy further frames that exist to the front of the buffer
                //       so they can be processed
                .Method => {
                    return self.dispatchMethod(expected_response);
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

        return false;
    }

    fn dispatchMethod(self: *Self, expected_response: ?ClassMethod) !bool {
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
                    if (class == proto.CHANNEL_CLASS and method == proto.Channel.CLOSE_METHOD) {
                        proto.dispatchCallback(self, class, method) catch |err| {
                            switch (err) {
                                error.ChannelError => {
                                    self.connection.free_channel(self.channel);
                                    return err;
                                },
                                else => return err,
                            }
                        };
                    }

                    if (class == proto.CONNECTION_CLASS and method == proto.Connection.CLOSE_METHOD) {
                        try proto.dispatchCallback(self, class, method);
                    }

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
    }
};

// TODO: This maybe needs to contain a channel id too
pub const ClassMethod = struct {
    class: u16 = 0,
    method: u16 = 0,
};
