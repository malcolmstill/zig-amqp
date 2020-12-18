const std = @import("std");
const fs = std.fs;
const Connector = @import("connector.zig").Connector;
const ClassMethod = @import("connector.zig").ClassMethod;
const WireBuffer = @import("wire.zig").WireBuffer;
const Table = @import("table.zig").Table;

// connection
pub const Connection = struct {
    const CONNECTION_CLASS = 10;

    // start
    const START_METHOD = 10;
    pub fn startSync(
        conn: *Connector,
        version_major: u8,
        version_minor: u8,
        server_properties: *Table,
        mechanisms: []const u8,
        locales: []const u8,
    ) !StartOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.START_METHOD);
        conn.tx_buffer.writeU8(version_major);
        conn.tx_buffer.writeU8(version_minor);
        conn.tx_buffer.writeTable(server_properties);
        conn.tx_buffer.writeLongString(mechanisms);
        conn.tx_buffer.writeLongString(locales);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Start ->\n", .{});
        return awaitStartOk(conn);
    }

    // start
    pub fn awaitStart(connector: *Connector) !Start {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.START_METHOD) {
                            const version_major = conn.rx_buffer.readU8();
                            const version_minor = conn.rx_buffer.readU8();
                            var server_properties = conn.rx_buffer.readTable();
                            const mechanisms = conn.rx_buffer.readLongString();
                            const locales = conn.rx_buffer.readLongString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Start\n", .{});
                            return Start{
                                .version_major = version_major,
                                .version_minor = version_minor,
                                .server_properties = server_properties,
                                .mechanisms = mechanisms,
                                .locales = locales,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const StartOk = struct {
        client_properties: *Table,
        mechanism: []const u8,
        response: []const u8,
        locale: []const u8,
    };

    // start-ok
    const START_OK_METHOD = 11;
    pub fn startOkAsync(
        conn: *Connector,
        client_properties: *Table,
        mechanism: []const u8,
        response: []const u8,
        locale: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.START_OK_METHOD);
        conn.tx_buffer.writeTable(client_properties);
        conn.tx_buffer.writeShortString(mechanism);
        conn.tx_buffer.writeLongString(response);
        conn.tx_buffer.writeShortString(locale);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Start_ok ->\n", .{});
    }

    // start_ok
    pub fn awaitStartOk(connector: *Connector) !StartOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.START_OK_METHOD) {
                            var client_properties = conn.rx_buffer.readTable();
                            const mechanism = conn.rx_buffer.readShortString();
                            const response = conn.rx_buffer.readLongString();
                            const locale = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Start_ok\n", .{});
                            return StartOk{
                                .client_properties = client_properties,
                                .mechanism = mechanism,
                                .response = response,
                                .locale = locale,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // secure
    const SECURE_METHOD = 20;
    pub fn secureSync(
        conn: *Connector,
        challenge: []const u8,
    ) !SecureOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.SECURE_METHOD);
        conn.tx_buffer.writeLongString(challenge);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Secure ->\n", .{});
        return awaitSecureOk(conn);
    }

    // secure
    pub fn awaitSecure(connector: *Connector) !Secure {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.SECURE_METHOD) {
                            const challenge = conn.rx_buffer.readLongString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Secure\n", .{});
                            return Secure{
                                .challenge = challenge,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const SecureOk = struct {
        response: []const u8,
    };

    // secure-ok
    const SECURE_OK_METHOD = 21;
    pub fn secureOkAsync(
        conn: *Connector,
        response: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.SECURE_OK_METHOD);
        conn.tx_buffer.writeLongString(response);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Secure_ok ->\n", .{});
    }

    // secure_ok
    pub fn awaitSecureOk(connector: *Connector) !SecureOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.SECURE_OK_METHOD) {
                            const response = conn.rx_buffer.readLongString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Secure_ok\n", .{});
                            return SecureOk{
                                .response = response,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // tune
    const TUNE_METHOD = 30;
    pub fn tuneSync(
        conn: *Connector,
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    ) !TuneOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.TUNE_METHOD);
        conn.tx_buffer.writeU16(channel_max);
        conn.tx_buffer.writeU32(frame_max);
        conn.tx_buffer.writeU16(heartbeat);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Tune ->\n", .{});
        return awaitTuneOk(conn);
    }

    // tune
    pub fn awaitTune(connector: *Connector) !Tune {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.TUNE_METHOD) {
                            const channel_max = conn.rx_buffer.readU16();
                            const frame_max = conn.rx_buffer.readU32();
                            const heartbeat = conn.rx_buffer.readU16();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Tune\n", .{});
                            return Tune{
                                .channel_max = channel_max,
                                .frame_max = frame_max,
                                .heartbeat = heartbeat,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const TuneOk = struct {
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    };

    // tune-ok
    const TUNE_OK_METHOD = 31;
    pub fn tuneOkAsync(
        conn: *Connector,
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.TUNE_OK_METHOD);
        conn.tx_buffer.writeU16(channel_max);
        conn.tx_buffer.writeU32(frame_max);
        conn.tx_buffer.writeU16(heartbeat);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Tune_ok ->\n", .{});
    }

    // tune_ok
    pub fn awaitTuneOk(connector: *Connector) !TuneOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.TUNE_OK_METHOD) {
                            const channel_max = conn.rx_buffer.readU16();
                            const frame_max = conn.rx_buffer.readU32();
                            const heartbeat = conn.rx_buffer.readU16();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Tune_ok\n", .{});
                            return TuneOk{
                                .channel_max = channel_max,
                                .frame_max = frame_max,
                                .heartbeat = heartbeat,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // open
    const OPEN_METHOD = 40;
    pub fn openSync(
        conn: *Connector,
        virtual_host: []const u8,
    ) !OpenOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.OPEN_METHOD);
        conn.tx_buffer.writeShortString(virtual_host);
        const reserved_1 = "";
        conn.tx_buffer.writeShortString(reserved_1);
        const reserved_2 = false;
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (reserved_2) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Open ->\n", .{});
        return awaitOpenOk(conn);
    }

    // open
    pub fn awaitOpen(connector: *Connector) !Open {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.OPEN_METHOD) {
                            const virtual_host = conn.rx_buffer.readShortString();
                            const reserved_1 = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const reserved_2 = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Open\n", .{});
                            return Open{
                                .virtual_host = virtual_host,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const OpenOk = struct {
        reserved_1: []const u8,
    };

    // open-ok
    const OPEN_OK_METHOD = 41;
    pub fn openOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.OPEN_OK_METHOD);
        const reserved_1 = "";
        conn.tx_buffer.writeShortString(reserved_1);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Open_ok ->\n", .{});
    }

    // open_ok
    pub fn awaitOpenOk(connector: *Connector) !OpenOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.OPEN_OK_METHOD) {
                            const reserved_1 = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Open_ok\n", .{});
                            return OpenOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // close
    const CLOSE_METHOD = 50;
    pub fn closeSync(
        conn: *Connector,
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    ) !CloseOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.CLOSE_METHOD);
        conn.tx_buffer.writeU16(reply_code);
        conn.tx_buffer.writeShortString(reply_text);
        conn.tx_buffer.writeU16(class_id);
        conn.tx_buffer.writeU16(method_id);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Close ->\n", .{});
        return awaitCloseOk(conn);
    }

    // close
    pub fn awaitClose(connector: *Connector) !Close {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CLOSE_METHOD) {
                            const reply_code = conn.rx_buffer.readU16();
                            const reply_text = conn.rx_buffer.readShortString();
                            const class_id = conn.rx_buffer.readU16();
                            const method_id = conn.rx_buffer.readU16();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Close\n", .{});
                            return Close{
                                .reply_code = reply_code,
                                .reply_text = reply_text,
                                .class_id = class_id,
                                .method_id = method_id,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const CloseOk = struct {};

    // close-ok
    const CLOSE_OK_METHOD = 51;
    pub fn closeOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.CLOSE_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Close_ok ->\n", .{});
    }

    // close_ok
    pub fn awaitCloseOk(connector: *Connector) !CloseOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CLOSE_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Close_ok\n", .{});
                            return CloseOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // blocked
    const BLOCKED_METHOD = 60;
    pub fn blockedAsync(
        conn: *Connector,
        reason: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.BLOCKED_METHOD);
        conn.tx_buffer.writeShortString(reason);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Blocked ->\n", .{});
    }

    // blocked
    pub fn awaitBlocked(connector: *Connector) !Blocked {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.BLOCKED_METHOD) {
                            const reason = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Blocked\n", .{});
                            return Blocked{
                                .reason = reason,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // unblocked
    const UNBLOCKED_METHOD = 61;
    pub fn unblockedAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.UNBLOCKED_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Connection.Unblocked ->\n", .{});
    }

    // unblocked
    pub fn awaitUnblocked(connector: *Connector) !Unblocked {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.UNBLOCKED_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Connection.Unblocked\n", .{});
                            return Unblocked{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }
};

// channel
pub const Channel = struct {
    const CHANNEL_CLASS = 20;

    // open
    const OPEN_METHOD = 10;
    pub fn openSync(
        conn: *Connector,
    ) !OpenOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.OPEN_METHOD);
        const reserved_1 = "";
        conn.tx_buffer.writeShortString(reserved_1);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Channel.Open ->\n", .{});
        return awaitOpenOk(conn);
    }

    // open
    pub fn awaitOpen(connector: *Connector) !Open {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.OPEN_METHOD) {
                            const reserved_1 = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Channel.Open\n", .{});
                            return Open{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const OpenOk = struct {
        reserved_1: []const u8,
    };

    // open-ok
    const OPEN_OK_METHOD = 11;
    pub fn openOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.OPEN_OK_METHOD);
        const reserved_1 = "";
        conn.tx_buffer.writeLongString(reserved_1);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Channel.Open_ok ->\n", .{});
    }

    // open_ok
    pub fn awaitOpenOk(connector: *Connector) !OpenOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.OPEN_OK_METHOD) {
                            const reserved_1 = conn.rx_buffer.readLongString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Channel.Open_ok\n", .{});
                            return OpenOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // flow
    const FLOW_METHOD = 20;
    pub fn flowSync(
        conn: *Connector,
        active: bool,
    ) !FlowOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.FLOW_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (active) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Channel.Flow ->\n", .{});
        return awaitFlowOk(conn);
    }

    // flow
    pub fn awaitFlow(connector: *Connector) !Flow {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.FLOW_METHOD) {
                            const bitset0 = conn.rx_buffer.readU8();
                            const active = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Channel.Flow\n", .{});
                            return Flow{
                                .active = active,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const FlowOk = struct {
        active: bool,
    };

    // flow-ok
    const FLOW_OK_METHOD = 21;
    pub fn flowOkAsync(
        conn: *Connector,
        active: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.FLOW_OK_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (active) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Channel.Flow_ok ->\n", .{});
    }

    // flow_ok
    pub fn awaitFlowOk(connector: *Connector) !FlowOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.FLOW_OK_METHOD) {
                            const bitset0 = conn.rx_buffer.readU8();
                            const active = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Channel.Flow_ok\n", .{});
                            return FlowOk{
                                .active = active,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // close
    const CLOSE_METHOD = 40;
    pub fn closeSync(
        conn: *Connector,
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    ) !CloseOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.CLOSE_METHOD);
        conn.tx_buffer.writeU16(reply_code);
        conn.tx_buffer.writeShortString(reply_text);
        conn.tx_buffer.writeU16(class_id);
        conn.tx_buffer.writeU16(method_id);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Channel.Close ->\n", .{});
        return awaitCloseOk(conn);
    }

    // close
    pub fn awaitClose(connector: *Connector) !Close {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CLOSE_METHOD) {
                            const reply_code = conn.rx_buffer.readU16();
                            const reply_text = conn.rx_buffer.readShortString();
                            const class_id = conn.rx_buffer.readU16();
                            const method_id = conn.rx_buffer.readU16();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Channel.Close\n", .{});
                            return Close{
                                .reply_code = reply_code,
                                .reply_text = reply_text,
                                .class_id = class_id,
                                .method_id = method_id,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const CloseOk = struct {};

    // close-ok
    const CLOSE_OK_METHOD = 41;
    pub fn closeOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.CLOSE_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Channel.Close_ok ->\n", .{});
    }

    // close_ok
    pub fn awaitCloseOk(connector: *Connector) !CloseOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CLOSE_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Channel.Close_ok\n", .{});
                            return CloseOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }
};

// exchange
pub const Exchange = struct {
    const EXCHANGE_CLASS = 40;

    // declare
    const DECLARE_METHOD = 10;
    pub fn declareSync(
        conn: *Connector,
        exchange: []const u8,
        tipe: []const u8,
        passive: bool,
        durable: bool,
        no_wait: bool,
        arguments: *Table,
    ) !DeclareOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, Exchange.DECLARE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(tipe);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (passive) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (durable) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        const reserved_2 = false;
        if (reserved_2) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        const reserved_3 = false;
        if (reserved_3) bitset0 |= (_bit << 3) else bitset0 &= ~(_bit << 3);
        if (no_wait) bitset0 |= (_bit << 4) else bitset0 &= ~(_bit << 4);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.writeTable(arguments);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Exchange.Declare ->\n", .{});
        return awaitDeclareOk(conn);
    }

    // declare
    pub fn awaitDeclare(connector: *Connector) !Declare {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == EXCHANGE_CLASS and method_header.method == Exchange.DECLARE_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const exchange = conn.rx_buffer.readShortString();
                            const tipe = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const passive = if (bitset0 & (1 << 0) == 0) true else false;
                            const durable = if (bitset0 & (1 << 1) == 0) true else false;
                            const reserved_2 = if (bitset0 & (1 << 2) == 0) true else false;
                            const reserved_3 = if (bitset0 & (1 << 3) == 0) true else false;
                            const no_wait = if (bitset0 & (1 << 4) == 0) true else false;
                            var arguments = conn.rx_buffer.readTable();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Exchange.Declare\n", .{});
                            return Declare{
                                .exchange = exchange,
                                .tipe = tipe,
                                .passive = passive,
                                .durable = durable,
                                .no_wait = no_wait,
                                .arguments = arguments,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const DeclareOk = struct {};

    // declare-ok
    const DECLARE_OK_METHOD = 11;
    pub fn declareOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, Exchange.DECLARE_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Exchange.Declare_ok ->\n", .{});
    }

    // declare_ok
    pub fn awaitDeclareOk(connector: *Connector) !DeclareOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == EXCHANGE_CLASS and method_header.method == Exchange.DECLARE_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Exchange.Declare_ok\n", .{});
                            return DeclareOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // delete
    const DELETE_METHOD = 20;
    pub fn deleteSync(
        conn: *Connector,
        exchange: []const u8,
        if_unused: bool,
        no_wait: bool,
    ) !DeleteOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, Exchange.DELETE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(exchange);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (if_unused) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (no_wait) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Exchange.Delete ->\n", .{});
        return awaitDeleteOk(conn);
    }

    // delete
    pub fn awaitDelete(connector: *Connector) !Delete {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == EXCHANGE_CLASS and method_header.method == Exchange.DELETE_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const exchange = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const if_unused = if (bitset0 & (1 << 0) == 0) true else false;
                            const no_wait = if (bitset0 & (1 << 1) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Exchange.Delete\n", .{});
                            return Delete{
                                .exchange = exchange,
                                .if_unused = if_unused,
                                .no_wait = no_wait,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const DeleteOk = struct {};

    // delete-ok
    const DELETE_OK_METHOD = 21;
    pub fn deleteOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, Exchange.DELETE_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Exchange.Delete_ok ->\n", .{});
    }

    // delete_ok
    pub fn awaitDeleteOk(connector: *Connector) !DeleteOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == EXCHANGE_CLASS and method_header.method == Exchange.DELETE_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Exchange.Delete_ok\n", .{});
                            return DeleteOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }
};

// queue
pub const Queue = struct {
    const QUEUE_CLASS = 50;

    // declare
    const DECLARE_METHOD = 10;
    pub fn declareSync(
        conn: *Connector,
        queue: []const u8,
        passive: bool,
        durable: bool,
        exclusive: bool,
        auto_delete: bool,
        no_wait: bool,
        arguments: *Table,
    ) !DeclareOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.DECLARE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (passive) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (durable) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        if (exclusive) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        if (auto_delete) bitset0 |= (_bit << 3) else bitset0 &= ~(_bit << 3);
        if (no_wait) bitset0 |= (_bit << 4) else bitset0 &= ~(_bit << 4);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.writeTable(arguments);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Queue.Declare ->\n", .{});
        return awaitDeclareOk(conn);
    }

    // declare
    pub fn awaitDeclare(connector: *Connector) !Declare {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == QUEUE_CLASS and method_header.method == Queue.DECLARE_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const passive = if (bitset0 & (1 << 0) == 0) true else false;
                            const durable = if (bitset0 & (1 << 1) == 0) true else false;
                            const exclusive = if (bitset0 & (1 << 2) == 0) true else false;
                            const auto_delete = if (bitset0 & (1 << 3) == 0) true else false;
                            const no_wait = if (bitset0 & (1 << 4) == 0) true else false;
                            var arguments = conn.rx_buffer.readTable();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Queue.Declare\n", .{});
                            return Declare{
                                .queue = queue,
                                .passive = passive,
                                .durable = durable,
                                .exclusive = exclusive,
                                .auto_delete = auto_delete,
                                .no_wait = no_wait,
                                .arguments = arguments,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const DeclareOk = struct {
        queue: []const u8,
        message_count: u32,
        consumer_count: u32,
    };

    // declare-ok
    const DECLARE_OK_METHOD = 11;
    pub fn declareOkAsync(
        conn: *Connector,
        queue: []const u8,
        message_count: u32,
        consumer_count: u32,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.DECLARE_OK_METHOD);
        conn.tx_buffer.writeShortString(queue);
        conn.tx_buffer.writeU32(message_count);
        conn.tx_buffer.writeU32(consumer_count);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Queue.Declare_ok ->\n", .{});
    }

    // declare_ok
    pub fn awaitDeclareOk(connector: *Connector) !DeclareOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == QUEUE_CLASS and method_header.method == Queue.DECLARE_OK_METHOD) {
                            const queue = conn.rx_buffer.readShortString();
                            const message_count = conn.rx_buffer.readU32();
                            const consumer_count = conn.rx_buffer.readU32();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Queue.Declare_ok\n", .{});
                            return DeclareOk{
                                .queue = queue,
                                .message_count = message_count,
                                .consumer_count = consumer_count,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // bind
    const BIND_METHOD = 20;
    pub fn bindSync(
        conn: *Connector,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        no_wait: bool,
        arguments: *Table,
    ) !BindOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.BIND_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(routing_key);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_wait) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.writeTable(arguments);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Queue.Bind ->\n", .{});
        return awaitBindOk(conn);
    }

    // bind
    pub fn awaitBind(connector: *Connector) !Bind {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == QUEUE_CLASS and method_header.method == Queue.BIND_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
                            var arguments = conn.rx_buffer.readTable();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Queue.Bind\n", .{});
                            return Bind{
                                .queue = queue,
                                .exchange = exchange,
                                .routing_key = routing_key,
                                .no_wait = no_wait,
                                .arguments = arguments,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const BindOk = struct {};

    // bind-ok
    const BIND_OK_METHOD = 21;
    pub fn bindOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.BIND_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Queue.Bind_ok ->\n", .{});
    }

    // bind_ok
    pub fn awaitBindOk(connector: *Connector) !BindOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == QUEUE_CLASS and method_header.method == Queue.BIND_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Queue.Bind_ok\n", .{});
                            return BindOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // unbind
    const UNBIND_METHOD = 50;
    pub fn unbindSync(
        conn: *Connector,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        arguments: *Table,
    ) !UnbindOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.UNBIND_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(routing_key);
        conn.tx_buffer.writeTable(arguments);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Queue.Unbind ->\n", .{});
        return awaitUnbindOk(conn);
    }

    // unbind
    pub fn awaitUnbind(connector: *Connector) !Unbind {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == QUEUE_CLASS and method_header.method == Queue.UNBIND_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            var arguments = conn.rx_buffer.readTable();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Queue.Unbind\n", .{});
                            return Unbind{
                                .queue = queue,
                                .exchange = exchange,
                                .routing_key = routing_key,
                                .arguments = arguments,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const UnbindOk = struct {};

    // unbind-ok
    const UNBIND_OK_METHOD = 51;
    pub fn unbindOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.UNBIND_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Queue.Unbind_ok ->\n", .{});
    }

    // unbind_ok
    pub fn awaitUnbindOk(connector: *Connector) !UnbindOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == QUEUE_CLASS and method_header.method == Queue.UNBIND_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Queue.Unbind_ok\n", .{});
                            return UnbindOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // purge
    const PURGE_METHOD = 30;
    pub fn purgeSync(
        conn: *Connector,
        queue: []const u8,
        no_wait: bool,
    ) !PurgeOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.PURGE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_wait) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Queue.Purge ->\n", .{});
        return awaitPurgeOk(conn);
    }

    // purge
    pub fn awaitPurge(connector: *Connector) !Purge {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == QUEUE_CLASS and method_header.method == Queue.PURGE_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Queue.Purge\n", .{});
                            return Purge{
                                .queue = queue,
                                .no_wait = no_wait,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const PurgeOk = struct {
        message_count: u32,
    };

    // purge-ok
    const PURGE_OK_METHOD = 31;
    pub fn purgeOkAsync(
        conn: *Connector,
        message_count: u32,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.PURGE_OK_METHOD);
        conn.tx_buffer.writeU32(message_count);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Queue.Purge_ok ->\n", .{});
    }

    // purge_ok
    pub fn awaitPurgeOk(connector: *Connector) !PurgeOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == QUEUE_CLASS and method_header.method == Queue.PURGE_OK_METHOD) {
                            const message_count = conn.rx_buffer.readU32();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Queue.Purge_ok\n", .{});
                            return PurgeOk{
                                .message_count = message_count,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // delete
    const DELETE_METHOD = 40;
    pub fn deleteSync(
        conn: *Connector,
        queue: []const u8,
        if_unused: bool,
        if_empty: bool,
        no_wait: bool,
    ) !DeleteOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.DELETE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (if_unused) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (if_empty) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        if (no_wait) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Queue.Delete ->\n", .{});
        return awaitDeleteOk(conn);
    }

    // delete
    pub fn awaitDelete(connector: *Connector) !Delete {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == QUEUE_CLASS and method_header.method == Queue.DELETE_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const if_unused = if (bitset0 & (1 << 0) == 0) true else false;
                            const if_empty = if (bitset0 & (1 << 1) == 0) true else false;
                            const no_wait = if (bitset0 & (1 << 2) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Queue.Delete\n", .{});
                            return Delete{
                                .queue = queue,
                                .if_unused = if_unused,
                                .if_empty = if_empty,
                                .no_wait = no_wait,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const DeleteOk = struct {
        message_count: u32,
    };

    // delete-ok
    const DELETE_OK_METHOD = 41;
    pub fn deleteOkAsync(
        conn: *Connector,
        message_count: u32,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.DELETE_OK_METHOD);
        conn.tx_buffer.writeU32(message_count);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Queue.Delete_ok ->\n", .{});
    }

    // delete_ok
    pub fn awaitDeleteOk(connector: *Connector) !DeleteOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == QUEUE_CLASS and method_header.method == Queue.DELETE_OK_METHOD) {
                            const message_count = conn.rx_buffer.readU32();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Queue.Delete_ok\n", .{});
                            return DeleteOk{
                                .message_count = message_count,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }
};

// basic
pub const Basic = struct {
    const BASIC_CLASS = 60;

    // qos
    const QOS_METHOD = 10;
    pub fn qosSync(
        conn: *Connector,
        prefetch_size: u32,
        prefetch_count: u16,
        global: bool,
    ) !QosOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.QOS_METHOD);
        conn.tx_buffer.writeU32(prefetch_size);
        conn.tx_buffer.writeU16(prefetch_count);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (global) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Qos ->\n", .{});
        return awaitQosOk(conn);
    }

    // qos
    pub fn awaitQos(connector: *Connector) !Qos {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.QOS_METHOD) {
                            const prefetch_size = conn.rx_buffer.readU32();
                            const prefetch_count = conn.rx_buffer.readU16();
                            const bitset0 = conn.rx_buffer.readU8();
                            const global = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Qos\n", .{});
                            return Qos{
                                .prefetch_size = prefetch_size,
                                .prefetch_count = prefetch_count,
                                .global = global,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const QosOk = struct {};

    // qos-ok
    const QOS_OK_METHOD = 11;
    pub fn qosOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.QOS_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Qos_ok ->\n", .{});
    }

    // qos_ok
    pub fn awaitQosOk(connector: *Connector) !QosOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.QOS_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Qos_ok\n", .{});
                            return QosOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // consume
    const CONSUME_METHOD = 20;
    pub fn consumeSync(
        conn: *Connector,
        queue: []const u8,
        consumer_tag: []const u8,
        no_local: bool,
        no_ack: bool,
        exclusive: bool,
        no_wait: bool,
        arguments: *Table,
    ) !ConsumeOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.CONSUME_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        conn.tx_buffer.writeShortString(consumer_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_local) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (no_ack) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        if (exclusive) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        if (no_wait) bitset0 |= (_bit << 3) else bitset0 &= ~(_bit << 3);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.writeTable(arguments);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Consume ->\n", .{});
        return awaitConsumeOk(conn);
    }

    // consume
    pub fn awaitConsume(connector: *Connector) !Consume {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.CONSUME_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const consumer_tag = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const no_local = if (bitset0 & (1 << 0) == 0) true else false;
                            const no_ack = if (bitset0 & (1 << 1) == 0) true else false;
                            const exclusive = if (bitset0 & (1 << 2) == 0) true else false;
                            const no_wait = if (bitset0 & (1 << 3) == 0) true else false;
                            var arguments = conn.rx_buffer.readTable();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Consume\n", .{});
                            return Consume{
                                .queue = queue,
                                .consumer_tag = consumer_tag,
                                .no_local = no_local,
                                .no_ack = no_ack,
                                .exclusive = exclusive,
                                .no_wait = no_wait,
                                .arguments = arguments,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const ConsumeOk = struct {
        consumer_tag: []const u8,
    };

    // consume-ok
    const CONSUME_OK_METHOD = 21;
    pub fn consumeOkAsync(
        conn: *Connector,
        consumer_tag: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.CONSUME_OK_METHOD);
        conn.tx_buffer.writeShortString(consumer_tag);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Consume_ok ->\n", .{});
    }

    // consume_ok
    pub fn awaitConsumeOk(connector: *Connector) !ConsumeOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.CONSUME_OK_METHOD) {
                            const consumer_tag = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Consume_ok\n", .{});
                            return ConsumeOk{
                                .consumer_tag = consumer_tag,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // cancel
    const CANCEL_METHOD = 30;
    pub fn cancelSync(
        conn: *Connector,
        consumer_tag: []const u8,
        no_wait: bool,
    ) !CancelOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.CANCEL_METHOD);
        conn.tx_buffer.writeShortString(consumer_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_wait) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Cancel ->\n", .{});
        return awaitCancelOk(conn);
    }

    // cancel
    pub fn awaitCancel(connector: *Connector) !Cancel {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.CANCEL_METHOD) {
                            const consumer_tag = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Cancel\n", .{});
                            return Cancel{
                                .consumer_tag = consumer_tag,
                                .no_wait = no_wait,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const CancelOk = struct {
        consumer_tag: []const u8,
    };

    // cancel-ok
    const CANCEL_OK_METHOD = 31;
    pub fn cancelOkAsync(
        conn: *Connector,
        consumer_tag: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.CANCEL_OK_METHOD);
        conn.tx_buffer.writeShortString(consumer_tag);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Cancel_ok ->\n", .{});
    }

    // cancel_ok
    pub fn awaitCancelOk(connector: *Connector) !CancelOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.CANCEL_OK_METHOD) {
                            const consumer_tag = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Cancel_ok\n", .{});
                            return CancelOk{
                                .consumer_tag = consumer_tag,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // publish
    const PUBLISH_METHOD = 40;
    pub fn publishAsync(
        conn: *Connector,
        exchange: []const u8,
        routing_key: []const u8,
        mandatory: bool,
        immediate: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.PUBLISH_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(routing_key);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (mandatory) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (immediate) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Publish ->\n", .{});
    }

    // publish
    pub fn awaitPublish(connector: *Connector) !Publish {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.PUBLISH_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const mandatory = if (bitset0 & (1 << 0) == 0) true else false;
                            const immediate = if (bitset0 & (1 << 1) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Publish\n", .{});
                            return Publish{
                                .exchange = exchange,
                                .routing_key = routing_key,
                                .mandatory = mandatory,
                                .immediate = immediate,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // return
    const RETURN_METHOD = 50;
    pub fn returnAsync(
        conn: *Connector,
        reply_code: u16,
        reply_text: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.RETURN_METHOD);
        conn.tx_buffer.writeU16(reply_code);
        conn.tx_buffer.writeShortString(reply_text);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(routing_key);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Return ->\n", .{});
    }

    // @"return"
    pub fn awaitReturn(connector: *Connector) !Return {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.RETURN_METHOD) {
                            const reply_code = conn.rx_buffer.readU16();
                            const reply_text = conn.rx_buffer.readShortString();
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Return\n", .{});
                            return Return{
                                .reply_code = reply_code,
                                .reply_text = reply_text,
                                .exchange = exchange,
                                .routing_key = routing_key,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // deliver
    const DELIVER_METHOD = 60;
    pub fn deliverAsync(
        conn: *Connector,
        consumer_tag: []const u8,
        delivery_tag: u64,
        redelivered: bool,
        exchange: []const u8,
        routing_key: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.DELIVER_METHOD);
        conn.tx_buffer.writeShortString(consumer_tag);
        conn.tx_buffer.writeU64(delivery_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (redelivered) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(routing_key);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Deliver ->\n", .{});
    }

    // deliver
    pub fn awaitDeliver(connector: *Connector) !Deliver {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.DELIVER_METHOD) {
                            const consumer_tag = conn.rx_buffer.readShortString();
                            const delivery_tag = conn.rx_buffer.readU64();
                            const bitset0 = conn.rx_buffer.readU8();
                            const redelivered = if (bitset0 & (1 << 0) == 0) true else false;
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Deliver\n", .{});
                            return Deliver{
                                .consumer_tag = consumer_tag,
                                .delivery_tag = delivery_tag,
                                .redelivered = redelivered,
                                .exchange = exchange,
                                .routing_key = routing_key,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // get
    const GET_METHOD = 70;
    pub fn getSync(
        conn: *Connector,
        queue: []const u8,
        no_ack: bool,
    ) !GetEmpty {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.GET_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_ack) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Get ->\n", .{});
        return awaitGetEmpty(conn);
    }

    // get
    pub fn awaitGet(connector: *Connector) !Get {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.GET_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const no_ack = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Get\n", .{});
                            return Get{
                                .queue = queue,
                                .no_ack = no_ack,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const GetEmpty = struct {
        reserved_1: []const u8,
    };

    // get-ok
    const GET_OK_METHOD = 71;
    pub fn getOkAsync(
        conn: *Connector,
        delivery_tag: u64,
        redelivered: bool,
        exchange: []const u8,
        routing_key: []const u8,
        message_count: u32,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.GET_OK_METHOD);
        conn.tx_buffer.writeU64(delivery_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (redelivered) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(routing_key);
        conn.tx_buffer.writeU32(message_count);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Get_ok ->\n", .{});
    }

    // get_ok
    pub fn awaitGetOk(connector: *Connector) !GetOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.GET_OK_METHOD) {
                            const delivery_tag = conn.rx_buffer.readU64();
                            const bitset0 = conn.rx_buffer.readU8();
                            const redelivered = if (bitset0 & (1 << 0) == 0) true else false;
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            const message_count = conn.rx_buffer.readU32();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Get_ok\n", .{});
                            return GetOk{
                                .delivery_tag = delivery_tag,
                                .redelivered = redelivered,
                                .exchange = exchange,
                                .routing_key = routing_key,
                                .message_count = message_count,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // get-empty
    const GET_EMPTY_METHOD = 72;
    pub fn getEmptyAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.GET_EMPTY_METHOD);
        const reserved_1 = "";
        conn.tx_buffer.writeShortString(reserved_1);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Get_empty ->\n", .{});
    }

    // get_empty
    pub fn awaitGetEmpty(connector: *Connector) !GetEmpty {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.GET_EMPTY_METHOD) {
                            const reserved_1 = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Get_empty\n", .{});
                            return GetEmpty{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // ack
    const ACK_METHOD = 80;
    pub fn ackAsync(
        conn: *Connector,
        delivery_tag: u64,
        multiple: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.ACK_METHOD);
        conn.tx_buffer.writeU64(delivery_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (multiple) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Ack ->\n", .{});
    }

    // ack
    pub fn awaitAck(connector: *Connector) !Ack {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.ACK_METHOD) {
                            const delivery_tag = conn.rx_buffer.readU64();
                            const bitset0 = conn.rx_buffer.readU8();
                            const multiple = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Ack\n", .{});
                            return Ack{
                                .delivery_tag = delivery_tag,
                                .multiple = multiple,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // reject
    const REJECT_METHOD = 90;
    pub fn rejectAsync(
        conn: *Connector,
        delivery_tag: u64,
        requeue: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.REJECT_METHOD);
        conn.tx_buffer.writeU64(delivery_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (requeue) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Reject ->\n", .{});
    }

    // reject
    pub fn awaitReject(connector: *Connector) !Reject {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.REJECT_METHOD) {
                            const delivery_tag = conn.rx_buffer.readU64();
                            const bitset0 = conn.rx_buffer.readU8();
                            const requeue = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Reject\n", .{});
                            return Reject{
                                .delivery_tag = delivery_tag,
                                .requeue = requeue,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // recover-async
    const RECOVER_ASYNC_METHOD = 100;
    pub fn recoverAsyncAsync(
        conn: *Connector,
        requeue: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.RECOVER_ASYNC_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (requeue) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Recover_async ->\n", .{});
    }

    // recover_async
    pub fn awaitRecoverAsync(connector: *Connector) !RecoverAsync {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.RECOVER_ASYNC_METHOD) {
                            const bitset0 = conn.rx_buffer.readU8();
                            const requeue = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Recover_async\n", .{});
                            return RecoverAsync{
                                .requeue = requeue,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // recover
    const RECOVER_METHOD = 110;
    pub fn recoverAsync(
        conn: *Connector,
        requeue: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.RECOVER_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (requeue) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Recover ->\n", .{});
    }

    // recover
    pub fn awaitRecover(connector: *Connector) !Recover {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.RECOVER_METHOD) {
                            const bitset0 = conn.rx_buffer.readU8();
                            const requeue = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Recover\n", .{});
                            return Recover{
                                .requeue = requeue,
                            };
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // recover-ok
    const RECOVER_OK_METHOD = 111;
    pub fn recoverOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.RECOVER_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Basic.Recover_ok ->\n", .{});
    }

    // recover_ok
    pub fn awaitRecoverOk(connector: *Connector) !RecoverOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == BASIC_CLASS and method_header.method == Basic.RECOVER_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Basic.Recover_ok\n", .{});
                            return RecoverOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }
};

// tx
pub const Tx = struct {
    const TX_CLASS = 90;

    // select
    const SELECT_METHOD = 10;
    pub fn selectSync(
        conn: *Connector,
    ) !SelectOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.SELECT_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Tx.Select ->\n", .{});
        return awaitSelectOk(conn);
    }

    // select
    pub fn awaitSelect(connector: *Connector) !Select {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == TX_CLASS and method_header.method == Tx.SELECT_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Tx.Select\n", .{});
                            return Select{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const SelectOk = struct {};

    // select-ok
    const SELECT_OK_METHOD = 11;
    pub fn selectOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.SELECT_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Tx.Select_ok ->\n", .{});
    }

    // select_ok
    pub fn awaitSelectOk(connector: *Connector) !SelectOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == TX_CLASS and method_header.method == Tx.SELECT_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Tx.Select_ok\n", .{});
                            return SelectOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // commit
    const COMMIT_METHOD = 20;
    pub fn commitSync(
        conn: *Connector,
    ) !CommitOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.COMMIT_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Tx.Commit ->\n", .{});
        return awaitCommitOk(conn);
    }

    // commit
    pub fn awaitCommit(connector: *Connector) !Commit {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == TX_CLASS and method_header.method == Tx.COMMIT_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Tx.Commit\n", .{});
                            return Commit{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const CommitOk = struct {};

    // commit-ok
    const COMMIT_OK_METHOD = 21;
    pub fn commitOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.COMMIT_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Tx.Commit_ok ->\n", .{});
    }

    // commit_ok
    pub fn awaitCommitOk(connector: *Connector) !CommitOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == TX_CLASS and method_header.method == Tx.COMMIT_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Tx.Commit_ok\n", .{});
                            return CommitOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    // rollback
    const ROLLBACK_METHOD = 30;
    pub fn rollbackSync(
        conn: *Connector,
    ) !RollbackOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.ROLLBACK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Tx.Rollback ->\n", .{});
        return awaitRollbackOk(conn);
    }

    // rollback
    pub fn awaitRollback(connector: *Connector) !Rollback {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == TX_CLASS and method_header.method == Tx.ROLLBACK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Tx.Rollback\n", .{});
                            return Rollback{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }

    pub const RollbackOk = struct {};

    // rollback-ok
    const ROLLBACK_OK_METHOD = 31;
    pub fn rollbackOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.ROLLBACK_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        if (std.builtin.mode == .Debug) std.debug.warn("Tx.Rollback_ok ->\n", .{});
    }

    // rollback_ok
    pub fn awaitRollbackOk(connector: *Connector) !RollbackOk {
        while (true) {
            while (self.rx_buffer.frameReady()) {
                const frame_header = try conn.getFrameHeader();
                switch (header.@"type") {
                    .Method => {
                        const method_header = try self.rx_buffer.readMethodHeader();
                        if (method_header.class == TX_CLASS and method_header.method == Tx.ROLLBACK_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            if (std.builtin.mode == .Debug) std.debug.warn("\t<- Tx.Rollback_ok\n", .{});
                            return RollbackOk{};
                        } else {
                            if (method_header.class == CONNECTION_CLASS and method_header.method == Connection.CANCEL_METHOD) {
                                try Connection.close_ok_async(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == CHANNEL_CLASS and method_header.method == Channel.CANCEL_METHOD) {
                                try Channel.close_ok_async(conn);
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        if (std.builtin.mode == .Debug) std.debug.warn("Got heartbeat\n", .{});
                        try self.rx_buffer.readEOF();
                    },
                    .Header => try conn.dispatchHeader(frame_header.size),
                    .Body => try conn.dispatchBody(frame_header.size),
                }
            }
        }
        unreachable;
    }
};
