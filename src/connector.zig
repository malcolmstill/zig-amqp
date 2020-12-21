const std = @import("std");
const os = std.os;
const fs = std.fs;
const proto = @import("protocol.zig");
const wire = @import("wire.zig");
const Header = @import("wire.zig").Header;
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

    pub fn sendHeader(self: *Self, size: u64, class: u16) !void {
        self.tx_buffer.writeHeader(self.channel, size, class);
        _ = try std.os.write(self.file.handle, self.tx_buffer.extent());
        self.tx_buffer.reset();
    }

    pub fn sendBody(self: *Self, body: []const u8) !void {
        self.tx_buffer.writeBody(self.channel, body);
        _ = try std.os.write(self.file.handle, self.tx_buffer.extent());
        self.tx_buffer.reset();
    }

    pub fn sendHeartbeat(self: *Self) !void {
        self.tx_buffer.writeHeartbeat();
        _ = try std.os.write(self.file.handle, self.tx_buffer.extent());
        self.tx_buffer.reset();
        std.log.debug("Heartbeat ->", .{});
    }

    pub fn awaitHeader(conn: *Connector) !Header {
        while (true) {
            if (!conn.rx_buffer.frameReady()) {
                // TODO: do we need to retry read (if n isn't as high as we expect)?
                const n = try os.read(conn.file.handle, conn.rx_buffer.remaining());
                conn.rx_buffer.incrementEnd(n);
                if (conn.rx_buffer.isFull()) conn.rx_buffer.shift();
                continue;
            }
            while (conn.rx_buffer.frameReady()) {
                const frame_header = try conn.rx_buffer.readFrameHeader();
                switch (frame_header.@"type") {
                    .Method => {
                        const method_header = try conn.rx_buffer.readMethodHeader();
                        if (method_header.class == 10 and method_header.method == 50) {
                            try proto.Connection.closeOkAsync(conn);
                            return error.ConnectionClose;
                        }
                        if (method_header.class == 20 and method_header.method == 40) {
                            try proto.Channel.closeOkAsync(conn);
                            return error.ChannelClose;
                        }
                        std.log.debug("awaitHeader: unexpected method {}.{}\n", .{ method_header.class, method_header.method });
                        return error.ImplementAsyncHandle;
                    },
                    .Heartbeat => {
                        std.log.debug("\t<- Heartbeat", .{});
                        try conn.rx_buffer.readEOF();
                        try conn.sendHeartbeat();
                    },
                    .Header => {
                        return conn.rx_buffer.readHeader(frame_header.size);
                    },
                    .Body => {
                        _ = try conn.rx_buffer.readBody(frame_header.size);
                    },
                }
            }
        }
        unreachable;
    }

    pub fn awaitBody(conn: *Connector) ![]u8 {
        while (true) {
            if (!conn.rx_buffer.frameReady()) {
                // TODO: do we need to retry read (if n isn't as high as we expect)?
                const n = try os.read(conn.file.handle, conn.rx_buffer.remaining());
                conn.rx_buffer.incrementEnd(n);
                if (conn.rx_buffer.isFull()) conn.rx_buffer.shift();
                continue;
            }
            while (conn.rx_buffer.frameReady()) {
                const frame_header = try conn.rx_buffer.readFrameHeader();
                switch (frame_header.@"type") {
                    .Method => {
                        const method_header = try conn.rx_buffer.readMethodHeader();
                        if (method_header.class == 10 and method_header.method == 50) {
                            try proto.Connection.closeOkAsync(conn);
                            return error.ConnectionClose;
                        }
                        if (method_header.class == 20 and method_header.method == 40) {
                            try proto.Channel.closeOkAsync(conn);
                            return error.ChannelClose;
                        }
                        std.log.debug("awaitBody: unexpected method {}.{}\n", .{ method_header.class, method_header.method });
                        return error.ImplementAsyncHandle;
                    },
                    .Heartbeat => {
                        std.log.debug("\t<- Heartbeat", .{});
                        try conn.rx_buffer.readEOF();
                        try conn.sendHeartbeat();
                    },
                    .Header => {
                        _ = try conn.rx_buffer.readHeader(frame_header.size);
                    },
                    .Body => {
                        return conn.rx_buffer.readBody(frame_header.size);
                    },
                }
            }
        }
        unreachable;
    }

    pub fn awaitMethod(conn: *Self, comptime T: type) !T {
        while (true) {
            if (!conn.rx_buffer.frameReady()) {
                // TODO: do we need to retry read (if n isn't as high as we expect)?
                const n = try os.read(conn.file.handle, conn.rx_buffer.remaining());
                conn.rx_buffer.incrementEnd(n);
                if (conn.rx_buffer.isFull()) conn.rx_buffer.shift();
                continue;
            }
            while (conn.rx_buffer.frameReady()) {
                const frame_header = try conn.rx_buffer.readFrameHeader();
                switch (frame_header.@"type") {
                    .Method => {
                        const method_header = try conn.rx_buffer.readMethodHeader();
                        if (T.CLASS == method_header.class and T.METHOD == method_header.method) {
                            return T.read(conn);
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                _ = try proto.Connection.Close.read(conn);
                                try proto.Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                _ = try proto.Channel.Close.read(conn);
                                try proto.Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            std.log.debug("awaitBody: unexpected method {}.{}\n", .{ method_header.class, method_header.method });
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("\t<- Heartbeat", .{});
                        try conn.rx_buffer.readEOF();
                        try conn.sendHeartbeat();
                    },
                    .Header => {
                        _ = try conn.rx_buffer.readHeader(frame_header.size);
                    },
                    .Body => {
                        _ = try conn.rx_buffer.readBody(frame_header.size);
                    },
                }
            }
        }
        unreachable;
    }
};
