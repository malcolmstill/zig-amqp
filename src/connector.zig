const std = @import("std");
const os = std.os;
const fs = std.fs;
const proto = @import("protocol.zig");
const wire = @import("wire.zig");
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

    pub fn getFrameHeader(self: *Self) !wire.FrameHeader {
        // If we don't have a full frame, block on read
        if (!self.rx_buffer.frameReady()) {
            const n = try os.read(self.file.handle, self.rx_buffer.remaining());
            self.rx_buffer.incrementEnd(n);
        }
        self.rx_buffer.reset();
        self.tx_buffer.reset();

        // 1. Attempt to read a frame header
        return self.rx_buffer.readFrameHeader();
    }

    // dispatch reads from our socket and dispatches methods in response
    // Where dispatch is invoked in initialising a request, we pass in an expected_response
    // ClassMethod that specifies what (synchronous) response we are expecting. If this value
    // is supplied and we receive an incorrect (synchronous) method we error, otherwise we
    // dispatch and return true. In the case
    // (expected_response supplied), if we receive an asynchronous response we dispatch it
    // but return true.
    pub fn dispatch(self: *Self, expected_response: ?ClassMethod) !bool {
        // If we don't have a full frame, block on read
        if (!self.rx_buffer.frameReady()) {
            const n = try os.read(self.file.handle, self.rx_buffer.remaining());
            self.rx_buffer.incrementEnd(n);
        }
        self.rx_buffer.reset();
        self.tx_buffer.reset();

        // if (std.builtin.mode == .Debug) self.rx_buffer.printSpan();
        defer self.rx_buffer.shift();

        // TODO: I think this should actually be while (self.rx_buffer.frameReady())
        //       On second thought, if we do that and continue to have the readFrameHeader
        //       in the loop, we'll basically be doing it twice every loop. With this
        //       we're only doing twice on the final loop where we don't have enough data.
        while (self.rx_buffer.frameReady()) : (i += 1) {
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
                    try self.rx_buffer.readEOF();
                    return false;
                },
                .Header => return self.dispatchHeader(header.size),
                .Body => return self.dispatchBody(header.size),
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

    pub fn dispatchHeader(self: *Self, frame_size: usize) !bool {
        const header = try self.rx_buffer.readHeader(frame_size);
        return false;
    }

    pub fn dispatchBody(self: *Self, frame_size: usize) bool {
        const body = self.rx_buffer.readBody(frame_size);
        std.debug.warn("body: {}\n", .{body});
        return false;
    }
};

// TODO: This maybe needs to contain a channel id too
pub const ClassMethod = struct {
    class: u16 = 0,
    method: u16 = 0,
};
