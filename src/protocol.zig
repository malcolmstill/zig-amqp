const std = @import("std");
const fs = std.fs;
const os = std.os;
const Connector = @import("connector.zig").Connector;
const WireBuffer = @import("wire.zig").WireBuffer;
const Table = @import("table.zig").Table;

pub const FRAME_METHOD = 1;
pub const FRAME_HEADER = 2;
pub const FRAME_BODY = 3;
pub const FRAME_HEARTBEAT = 8;
pub const FRAME_MIN_SIZE = 4096;
pub const FRAME_END = 206;
pub const REPLY_SUCCESS = 200;
pub const CONTENT_TOO_LARGE = 311;
pub const NO_CONSUMERS = 313;
pub const CONNECTION_FORCED = 320;
pub const INVALID_PATH = 402;
pub const ACCESS_REFUSED = 403;
pub const NOT_FOUND = 404;
pub const RESOURCE_LOCKED = 405;
pub const PRECONDITION_FAILED = 406;
pub const FRAME_ERROR = 501;
pub const SYNTAX_ERROR = 502;
pub const COMMAND_INVALID = 503;
pub const CHANNEL_ERROR = 504;
pub const UNEXPECTED_FRAME = 505;
pub const RESOURCE_ERROR = 506;
pub const NOT_ALLOWED = 530;
pub const NOT_IMPLEMENTED = 540;
pub const INTERNAL_ERROR = 541;

// connection
pub const Connection = struct {
    pub const CONNECTION_CLASS = 10;

    // start

    pub const Start = struct {
        version_major: u8,
        version_minor: u8,
        server_properties: Table,
        mechanisms: []const u8,
        locales: []const u8,
    };
    pub const START_METHOD = 10;
    pub fn startSync(
        conn: *Connector,
        version_major: u8,
        version_minor: u8,
        server_properties: ?*Table,
        mechanisms: []const u8,
        locales: []const u8,
    ) !StartOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, START_METHOD);
        conn.tx_buffer.writeU8(version_major);
        conn.tx_buffer.writeU8(version_minor);
        conn.tx_buffer.writeTable(server_properties);
        conn.tx_buffer.writeLongString(mechanisms);
        conn.tx_buffer.writeLongString(locales);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Start ->", .{conn.channel});
        return awaitStartOk(conn);
    }

    // start
    pub fn awaitStart(conn: *Connector) !Start {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == START_METHOD) {
                            const version_major = conn.rx_buffer.readU8();
                            const version_minor = conn.rx_buffer.readU8();
                            var server_properties = conn.rx_buffer.readTable();
                            const mechanisms = conn.rx_buffer.readLongString();
                            const locales = conn.rx_buffer.readLongString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Start", .{conn.channel});
                            return Start{
                                .version_major = version_major,
                                .version_minor = version_minor,
                                .server_properties = server_properties,
                                .mechanisms = mechanisms,
                                .locales = locales,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // start-ok

    pub const StartOk = struct {
        client_properties: Table,
        mechanism: []const u8,
        response: []const u8,
        locale: []const u8,
    };
    pub const START_OK_METHOD = 11;
    pub fn startOkAsync(
        conn: *Connector,
        client_properties: ?*Table,
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Start_ok ->", .{conn.channel});
    }

    // start_ok
    pub fn awaitStartOk(conn: *Connector) !StartOk {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == START_OK_METHOD) {
                            var client_properties = conn.rx_buffer.readTable();
                            const mechanism = conn.rx_buffer.readShortString();
                            const response = conn.rx_buffer.readLongString();
                            const locale = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Start_ok", .{conn.channel});
                            return StartOk{
                                .client_properties = client_properties,
                                .mechanism = mechanism,
                                .response = response,
                                .locale = locale,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // secure

    pub const Secure = struct {
        challenge: []const u8,
    };
    pub const SECURE_METHOD = 20;
    pub fn secureSync(
        conn: *Connector,
        challenge: []const u8,
    ) !SecureOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, SECURE_METHOD);
        conn.tx_buffer.writeLongString(challenge);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Secure ->", .{conn.channel});
        return awaitSecureOk(conn);
    }

    // secure
    pub fn awaitSecure(conn: *Connector) !Secure {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == SECURE_METHOD) {
                            const challenge = conn.rx_buffer.readLongString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Secure", .{conn.channel});
                            return Secure{
                                .challenge = challenge,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // secure-ok

    pub const SecureOk = struct {
        response: []const u8,
    };
    pub const SECURE_OK_METHOD = 21;
    pub fn secureOkAsync(
        conn: *Connector,
        response: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.SECURE_OK_METHOD);
        conn.tx_buffer.writeLongString(response);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Secure_ok ->", .{conn.channel});
    }

    // secure_ok
    pub fn awaitSecureOk(conn: *Connector) !SecureOk {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == SECURE_OK_METHOD) {
                            const response = conn.rx_buffer.readLongString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Secure_ok", .{conn.channel});
                            return SecureOk{
                                .response = response,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // tune

    pub const Tune = struct {
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    };
    pub const TUNE_METHOD = 30;
    pub fn tuneSync(
        conn: *Connector,
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    ) !TuneOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, TUNE_METHOD);
        conn.tx_buffer.writeU16(channel_max);
        conn.tx_buffer.writeU32(frame_max);
        conn.tx_buffer.writeU16(heartbeat);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Tune ->", .{conn.channel});
        return awaitTuneOk(conn);
    }

    // tune
    pub fn awaitTune(conn: *Connector) !Tune {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == TUNE_METHOD) {
                            const channel_max = conn.rx_buffer.readU16();
                            const frame_max = conn.rx_buffer.readU32();
                            const heartbeat = conn.rx_buffer.readU16();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Tune", .{conn.channel});
                            return Tune{
                                .channel_max = channel_max,
                                .frame_max = frame_max,
                                .heartbeat = heartbeat,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // tune-ok

    pub const TuneOk = struct {
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    };
    pub const TUNE_OK_METHOD = 31;
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Tune_ok ->", .{conn.channel});
    }

    // tune_ok
    pub fn awaitTuneOk(conn: *Connector) !TuneOk {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == TUNE_OK_METHOD) {
                            const channel_max = conn.rx_buffer.readU16();
                            const frame_max = conn.rx_buffer.readU32();
                            const heartbeat = conn.rx_buffer.readU16();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Tune_ok", .{conn.channel});
                            return TuneOk{
                                .channel_max = channel_max,
                                .frame_max = frame_max,
                                .heartbeat = heartbeat,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // open

    pub const Open = struct {
        virtual_host: []const u8,
        reserved_1: []const u8,
        reserved_2: bool,
    };
    pub const OPEN_METHOD = 40;
    pub fn openSync(
        conn: *Connector,
        virtual_host: []const u8,
    ) !OpenOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, OPEN_METHOD);
        conn.tx_buffer.writeShortString(virtual_host);
        const reserved_1 = "";
        conn.tx_buffer.writeShortString(reserved_1);
        const reserved_2 = false;
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (reserved_2) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Open ->", .{conn.channel});
        return awaitOpenOk(conn);
    }

    // open
    pub fn awaitOpen(conn: *Connector) !Open {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == OPEN_METHOD) {
                            const virtual_host = conn.rx_buffer.readShortString();
                            const reserved_1 = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const reserved_2 = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Open", .{conn.channel});
                            return Open{
                                .virtual_host = virtual_host,
                                .reserved_1 = reserved_1,
                                .reserved_2 = reserved_2,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // open-ok

    pub const OpenOk = struct {
        reserved_1: []const u8,
    };
    pub const OPEN_OK_METHOD = 41;
    pub fn openOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.OPEN_OK_METHOD);
        const reserved_1 = "";
        conn.tx_buffer.writeShortString(reserved_1);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Open_ok ->", .{conn.channel});
    }

    // open_ok
    pub fn awaitOpenOk(conn: *Connector) !OpenOk {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == OPEN_OK_METHOD) {
                            const reserved_1 = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Open_ok", .{conn.channel});
                            return OpenOk{
                                .reserved_1 = reserved_1,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // close

    pub const Close = struct {
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    };
    pub const CLOSE_METHOD = 50;
    pub fn closeSync(
        conn: *Connector,
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    ) !CloseOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, CLOSE_METHOD);
        conn.tx_buffer.writeU16(reply_code);
        conn.tx_buffer.writeShortString(reply_text);
        conn.tx_buffer.writeU16(class_id);
        conn.tx_buffer.writeU16(method_id);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Close ->", .{conn.channel});
        return awaitCloseOk(conn);
    }

    // close
    pub fn awaitClose(conn: *Connector) !Close {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == CLOSE_METHOD) {
                            const reply_code = conn.rx_buffer.readU16();
                            const reply_text = conn.rx_buffer.readShortString();
                            const class_id = conn.rx_buffer.readU16();
                            const method_id = conn.rx_buffer.readU16();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Close", .{conn.channel});
                            return Close{
                                .reply_code = reply_code,
                                .reply_text = reply_text,
                                .class_id = class_id,
                                .method_id = method_id,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // close-ok

    pub const CloseOk = struct {};
    pub const CLOSE_OK_METHOD = 51;
    pub fn closeOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.CLOSE_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Close_ok ->", .{conn.channel});
    }

    // close_ok
    pub fn awaitCloseOk(conn: *Connector) !CloseOk {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == CLOSE_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Close_ok", .{conn.channel});
                            return CloseOk{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // blocked

    pub const Blocked = struct {
        reason: []const u8,
    };
    pub const BLOCKED_METHOD = 60;
    pub fn blockedAsync(
        conn: *Connector,
        reason: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.BLOCKED_METHOD);
        conn.tx_buffer.writeShortString(reason);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Blocked ->", .{conn.channel});
    }

    // blocked
    pub fn awaitBlocked(conn: *Connector) !Blocked {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == BLOCKED_METHOD) {
                            const reason = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Blocked", .{conn.channel});
                            return Blocked{
                                .reason = reason,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // unblocked

    pub const Unblocked = struct {};
    pub const UNBLOCKED_METHOD = 61;
    pub fn unblockedAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.UNBLOCKED_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Connection@{}.Unblocked ->", .{conn.channel});
    }

    // unblocked
    pub fn awaitUnblocked(conn: *Connector) !Unblocked {
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
                        if (method_header.class == CONNECTION_CLASS and method_header.method == UNBLOCKED_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Connection@{}.Unblocked", .{conn.channel});
                            return Unblocked{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

// channel
pub const Channel = struct {
    pub const CHANNEL_CLASS = 20;

    // open

    pub const Open = struct {
        reserved_1: []const u8,
    };
    pub const OPEN_METHOD = 10;
    pub fn openSync(
        conn: *Connector,
    ) !OpenOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, OPEN_METHOD);
        const reserved_1 = "";
        conn.tx_buffer.writeShortString(reserved_1);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Channel@{}.Open ->", .{conn.channel});
        return awaitOpenOk(conn);
    }

    // open
    pub fn awaitOpen(conn: *Connector) !Open {
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
                        if (method_header.class == CHANNEL_CLASS and method_header.method == OPEN_METHOD) {
                            const reserved_1 = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Channel@{}.Open", .{conn.channel});
                            return Open{
                                .reserved_1 = reserved_1,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // open-ok

    pub const OpenOk = struct {
        reserved_1: []const u8,
    };
    pub const OPEN_OK_METHOD = 11;
    pub fn openOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.OPEN_OK_METHOD);
        const reserved_1 = "";
        conn.tx_buffer.writeLongString(reserved_1);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Channel@{}.Open_ok ->", .{conn.channel});
    }

    // open_ok
    pub fn awaitOpenOk(conn: *Connector) !OpenOk {
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
                        if (method_header.class == CHANNEL_CLASS and method_header.method == OPEN_OK_METHOD) {
                            const reserved_1 = conn.rx_buffer.readLongString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Channel@{}.Open_ok", .{conn.channel});
                            return OpenOk{
                                .reserved_1 = reserved_1,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // flow

    pub const Flow = struct {
        active: bool,
    };
    pub const FLOW_METHOD = 20;
    pub fn flowSync(
        conn: *Connector,
        active: bool,
    ) !FlowOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, FLOW_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (active) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Channel@{}.Flow ->", .{conn.channel});
        return awaitFlowOk(conn);
    }

    // flow
    pub fn awaitFlow(conn: *Connector) !Flow {
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
                        if (method_header.class == CHANNEL_CLASS and method_header.method == FLOW_METHOD) {
                            const bitset0 = conn.rx_buffer.readU8();
                            const active = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Channel@{}.Flow", .{conn.channel});
                            return Flow{
                                .active = active,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // flow-ok

    pub const FlowOk = struct {
        active: bool,
    };
    pub const FLOW_OK_METHOD = 21;
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Channel@{}.Flow_ok ->", .{conn.channel});
    }

    // flow_ok
    pub fn awaitFlowOk(conn: *Connector) !FlowOk {
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
                        if (method_header.class == CHANNEL_CLASS and method_header.method == FLOW_OK_METHOD) {
                            const bitset0 = conn.rx_buffer.readU8();
                            const active = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Channel@{}.Flow_ok", .{conn.channel});
                            return FlowOk{
                                .active = active,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // close

    pub const Close = struct {
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    };
    pub const CLOSE_METHOD = 40;
    pub fn closeSync(
        conn: *Connector,
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    ) !CloseOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, CLOSE_METHOD);
        conn.tx_buffer.writeU16(reply_code);
        conn.tx_buffer.writeShortString(reply_text);
        conn.tx_buffer.writeU16(class_id);
        conn.tx_buffer.writeU16(method_id);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Channel@{}.Close ->", .{conn.channel});
        return awaitCloseOk(conn);
    }

    // close
    pub fn awaitClose(conn: *Connector) !Close {
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
                        if (method_header.class == CHANNEL_CLASS and method_header.method == CLOSE_METHOD) {
                            const reply_code = conn.rx_buffer.readU16();
                            const reply_text = conn.rx_buffer.readShortString();
                            const class_id = conn.rx_buffer.readU16();
                            const method_id = conn.rx_buffer.readU16();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Channel@{}.Close", .{conn.channel});
                            return Close{
                                .reply_code = reply_code,
                                .reply_text = reply_text,
                                .class_id = class_id,
                                .method_id = method_id,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // close-ok

    pub const CloseOk = struct {};
    pub const CLOSE_OK_METHOD = 41;
    pub fn closeOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.CLOSE_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Channel@{}.Close_ok ->", .{conn.channel});
    }

    // close_ok
    pub fn awaitCloseOk(conn: *Connector) !CloseOk {
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
                        if (method_header.class == CHANNEL_CLASS and method_header.method == CLOSE_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Channel@{}.Close_ok", .{conn.channel});
                            return CloseOk{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

// exchange
pub const Exchange = struct {
    pub const EXCHANGE_CLASS = 40;

    // declare

    pub const Declare = struct {
        reserved_1: u16,
        exchange: []const u8,
        tipe: []const u8,
        passive: bool,
        durable: bool,
        reserved_2: bool,
        reserved_3: bool,
        no_wait: bool,
        arguments: Table,
    };
    pub const DECLARE_METHOD = 10;
    pub fn declareSync(
        conn: *Connector,
        exchange: []const u8,
        tipe: []const u8,
        passive: bool,
        durable: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) !DeclareOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, DECLARE_METHOD);
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Exchange@{}.Declare ->", .{conn.channel});
        return awaitDeclareOk(conn);
    }

    // declare
    pub fn awaitDeclare(conn: *Connector) !Declare {
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
                        if (method_header.class == EXCHANGE_CLASS and method_header.method == DECLARE_METHOD) {
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
                            std.log.debug("\t<- Exchange@{}.Declare", .{conn.channel});
                            return Declare{
                                .reserved_1 = reserved_1,
                                .exchange = exchange,
                                .tipe = tipe,
                                .passive = passive,
                                .durable = durable,
                                .reserved_2 = reserved_2,
                                .reserved_3 = reserved_3,
                                .no_wait = no_wait,
                                .arguments = arguments,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // declare-ok

    pub const DeclareOk = struct {};
    pub const DECLARE_OK_METHOD = 11;
    pub fn declareOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, Exchange.DECLARE_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Exchange@{}.Declare_ok ->", .{conn.channel});
    }

    // declare_ok
    pub fn awaitDeclareOk(conn: *Connector) !DeclareOk {
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
                        if (method_header.class == EXCHANGE_CLASS and method_header.method == DECLARE_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Exchange@{}.Declare_ok", .{conn.channel});
                            return DeclareOk{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // delete

    pub const Delete = struct {
        reserved_1: u16,
        exchange: []const u8,
        if_unused: bool,
        no_wait: bool,
    };
    pub const DELETE_METHOD = 20;
    pub fn deleteSync(
        conn: *Connector,
        exchange: []const u8,
        if_unused: bool,
        no_wait: bool,
    ) !DeleteOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, DELETE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(exchange);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (if_unused) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (no_wait) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Exchange@{}.Delete ->", .{conn.channel});
        return awaitDeleteOk(conn);
    }

    // delete
    pub fn awaitDelete(conn: *Connector) !Delete {
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
                        if (method_header.class == EXCHANGE_CLASS and method_header.method == DELETE_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const exchange = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const if_unused = if (bitset0 & (1 << 0) == 0) true else false;
                            const no_wait = if (bitset0 & (1 << 1) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Exchange@{}.Delete", .{conn.channel});
                            return Delete{
                                .reserved_1 = reserved_1,
                                .exchange = exchange,
                                .if_unused = if_unused,
                                .no_wait = no_wait,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // delete-ok

    pub const DeleteOk = struct {};
    pub const DELETE_OK_METHOD = 21;
    pub fn deleteOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, Exchange.DELETE_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Exchange@{}.Delete_ok ->", .{conn.channel});
    }

    // delete_ok
    pub fn awaitDeleteOk(conn: *Connector) !DeleteOk {
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
                        if (method_header.class == EXCHANGE_CLASS and method_header.method == DELETE_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Exchange@{}.Delete_ok", .{conn.channel});
                            return DeleteOk{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

// queue
pub const Queue = struct {
    pub const QUEUE_CLASS = 50;

    // declare

    pub const Declare = struct {
        reserved_1: u16,
        queue: []const u8,
        passive: bool,
        durable: bool,
        exclusive: bool,
        auto_delete: bool,
        no_wait: bool,
        arguments: Table,
    };
    pub const DECLARE_METHOD = 10;
    pub fn declareSync(
        conn: *Connector,
        queue: []const u8,
        passive: bool,
        durable: bool,
        exclusive: bool,
        auto_delete: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) !DeclareOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, DECLARE_METHOD);
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Queue@{}.Declare ->", .{conn.channel});
        return awaitDeclareOk(conn);
    }

    // declare
    pub fn awaitDeclare(conn: *Connector) !Declare {
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
                        if (method_header.class == QUEUE_CLASS and method_header.method == DECLARE_METHOD) {
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
                            std.log.debug("\t<- Queue@{}.Declare", .{conn.channel});
                            return Declare{
                                .reserved_1 = reserved_1,
                                .queue = queue,
                                .passive = passive,
                                .durable = durable,
                                .exclusive = exclusive,
                                .auto_delete = auto_delete,
                                .no_wait = no_wait,
                                .arguments = arguments,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // declare-ok

    pub const DeclareOk = struct {
        queue: []const u8,
        message_count: u32,
        consumer_count: u32,
    };
    pub const DECLARE_OK_METHOD = 11;
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Queue@{}.Declare_ok ->", .{conn.channel});
    }

    // declare_ok
    pub fn awaitDeclareOk(conn: *Connector) !DeclareOk {
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
                        if (method_header.class == QUEUE_CLASS and method_header.method == DECLARE_OK_METHOD) {
                            const queue = conn.rx_buffer.readShortString();
                            const message_count = conn.rx_buffer.readU32();
                            const consumer_count = conn.rx_buffer.readU32();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Queue@{}.Declare_ok", .{conn.channel});
                            return DeclareOk{
                                .queue = queue,
                                .message_count = message_count,
                                .consumer_count = consumer_count,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // bind

    pub const Bind = struct {
        reserved_1: u16,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        no_wait: bool,
        arguments: Table,
    };
    pub const BIND_METHOD = 20;
    pub fn bindSync(
        conn: *Connector,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        no_wait: bool,
        arguments: ?*Table,
    ) !BindOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, BIND_METHOD);
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Queue@{}.Bind ->", .{conn.channel});
        return awaitBindOk(conn);
    }

    // bind
    pub fn awaitBind(conn: *Connector) !Bind {
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
                        if (method_header.class == QUEUE_CLASS and method_header.method == BIND_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
                            var arguments = conn.rx_buffer.readTable();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Queue@{}.Bind", .{conn.channel});
                            return Bind{
                                .reserved_1 = reserved_1,
                                .queue = queue,
                                .exchange = exchange,
                                .routing_key = routing_key,
                                .no_wait = no_wait,
                                .arguments = arguments,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // bind-ok

    pub const BindOk = struct {};
    pub const BIND_OK_METHOD = 21;
    pub fn bindOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.BIND_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Queue@{}.Bind_ok ->", .{conn.channel});
    }

    // bind_ok
    pub fn awaitBindOk(conn: *Connector) !BindOk {
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
                        if (method_header.class == QUEUE_CLASS and method_header.method == BIND_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Queue@{}.Bind_ok", .{conn.channel});
                            return BindOk{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // unbind

    pub const Unbind = struct {
        reserved_1: u16,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        arguments: Table,
    };
    pub const UNBIND_METHOD = 50;
    pub fn unbindSync(
        conn: *Connector,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        arguments: ?*Table,
    ) !UnbindOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, UNBIND_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(routing_key);
        conn.tx_buffer.writeTable(arguments);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Queue@{}.Unbind ->", .{conn.channel});
        return awaitUnbindOk(conn);
    }

    // unbind
    pub fn awaitUnbind(conn: *Connector) !Unbind {
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
                        if (method_header.class == QUEUE_CLASS and method_header.method == UNBIND_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            var arguments = conn.rx_buffer.readTable();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Queue@{}.Unbind", .{conn.channel});
                            return Unbind{
                                .reserved_1 = reserved_1,
                                .queue = queue,
                                .exchange = exchange,
                                .routing_key = routing_key,
                                .arguments = arguments,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // unbind-ok

    pub const UnbindOk = struct {};
    pub const UNBIND_OK_METHOD = 51;
    pub fn unbindOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.UNBIND_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Queue@{}.Unbind_ok ->", .{conn.channel});
    }

    // unbind_ok
    pub fn awaitUnbindOk(conn: *Connector) !UnbindOk {
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
                        if (method_header.class == QUEUE_CLASS and method_header.method == UNBIND_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Queue@{}.Unbind_ok", .{conn.channel});
                            return UnbindOk{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // purge

    pub const Purge = struct {
        reserved_1: u16,
        queue: []const u8,
        no_wait: bool,
    };
    pub const PURGE_METHOD = 30;
    pub fn purgeSync(
        conn: *Connector,
        queue: []const u8,
        no_wait: bool,
    ) !PurgeOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, PURGE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_wait) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Queue@{}.Purge ->", .{conn.channel});
        return awaitPurgeOk(conn);
    }

    // purge
    pub fn awaitPurge(conn: *Connector) !Purge {
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
                        if (method_header.class == QUEUE_CLASS and method_header.method == PURGE_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Queue@{}.Purge", .{conn.channel});
                            return Purge{
                                .reserved_1 = reserved_1,
                                .queue = queue,
                                .no_wait = no_wait,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // purge-ok

    pub const PurgeOk = struct {
        message_count: u32,
    };
    pub const PURGE_OK_METHOD = 31;
    pub fn purgeOkAsync(
        conn: *Connector,
        message_count: u32,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.PURGE_OK_METHOD);
        conn.tx_buffer.writeU32(message_count);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Queue@{}.Purge_ok ->", .{conn.channel});
    }

    // purge_ok
    pub fn awaitPurgeOk(conn: *Connector) !PurgeOk {
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
                        if (method_header.class == QUEUE_CLASS and method_header.method == PURGE_OK_METHOD) {
                            const message_count = conn.rx_buffer.readU32();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Queue@{}.Purge_ok", .{conn.channel});
                            return PurgeOk{
                                .message_count = message_count,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // delete

    pub const Delete = struct {
        reserved_1: u16,
        queue: []const u8,
        if_unused: bool,
        if_empty: bool,
        no_wait: bool,
    };
    pub const DELETE_METHOD = 40;
    pub fn deleteSync(
        conn: *Connector,
        queue: []const u8,
        if_unused: bool,
        if_empty: bool,
        no_wait: bool,
    ) !DeleteOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, DELETE_METHOD);
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Queue@{}.Delete ->", .{conn.channel});
        return awaitDeleteOk(conn);
    }

    // delete
    pub fn awaitDelete(conn: *Connector) !Delete {
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
                        if (method_header.class == QUEUE_CLASS and method_header.method == DELETE_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const if_unused = if (bitset0 & (1 << 0) == 0) true else false;
                            const if_empty = if (bitset0 & (1 << 1) == 0) true else false;
                            const no_wait = if (bitset0 & (1 << 2) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Queue@{}.Delete", .{conn.channel});
                            return Delete{
                                .reserved_1 = reserved_1,
                                .queue = queue,
                                .if_unused = if_unused,
                                .if_empty = if_empty,
                                .no_wait = no_wait,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // delete-ok

    pub const DeleteOk = struct {
        message_count: u32,
    };
    pub const DELETE_OK_METHOD = 41;
    pub fn deleteOkAsync(
        conn: *Connector,
        message_count: u32,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.DELETE_OK_METHOD);
        conn.tx_buffer.writeU32(message_count);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Queue@{}.Delete_ok ->", .{conn.channel});
    }

    // delete_ok
    pub fn awaitDeleteOk(conn: *Connector) !DeleteOk {
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
                        if (method_header.class == QUEUE_CLASS and method_header.method == DELETE_OK_METHOD) {
                            const message_count = conn.rx_buffer.readU32();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Queue@{}.Delete_ok", .{conn.channel});
                            return DeleteOk{
                                .message_count = message_count,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

// basic
pub const Basic = struct {
    pub const BASIC_CLASS = 60;

    // qos

    pub const Qos = struct {
        prefetch_size: u32,
        prefetch_count: u16,
        global: bool,
    };
    pub const QOS_METHOD = 10;
    pub fn qosSync(
        conn: *Connector,
        prefetch_size: u32,
        prefetch_count: u16,
        global: bool,
    ) !QosOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, QOS_METHOD);
        conn.tx_buffer.writeU32(prefetch_size);
        conn.tx_buffer.writeU16(prefetch_count);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (global) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Qos ->", .{conn.channel});
        return awaitQosOk(conn);
    }

    // qos
    pub fn awaitQos(conn: *Connector) !Qos {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == QOS_METHOD) {
                            const prefetch_size = conn.rx_buffer.readU32();
                            const prefetch_count = conn.rx_buffer.readU16();
                            const bitset0 = conn.rx_buffer.readU8();
                            const global = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Qos", .{conn.channel});
                            return Qos{
                                .prefetch_size = prefetch_size,
                                .prefetch_count = prefetch_count,
                                .global = global,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // qos-ok

    pub const QosOk = struct {};
    pub const QOS_OK_METHOD = 11;
    pub fn qosOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.QOS_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Qos_ok ->", .{conn.channel});
    }

    // qos_ok
    pub fn awaitQosOk(conn: *Connector) !QosOk {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == QOS_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Qos_ok", .{conn.channel});
                            return QosOk{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // consume

    pub const Consume = struct {
        reserved_1: u16,
        queue: []const u8,
        consumer_tag: []const u8,
        no_local: bool,
        no_ack: bool,
        exclusive: bool,
        no_wait: bool,
        arguments: Table,
    };
    pub const CONSUME_METHOD = 20;
    pub fn consumeSync(
        conn: *Connector,
        queue: []const u8,
        consumer_tag: []const u8,
        no_local: bool,
        no_ack: bool,
        exclusive: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) !ConsumeOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, CONSUME_METHOD);
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Consume ->", .{conn.channel});
        return awaitConsumeOk(conn);
    }

    // consume
    pub fn awaitConsume(conn: *Connector) !Consume {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == CONSUME_METHOD) {
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
                            std.log.debug("\t<- Basic@{}.Consume", .{conn.channel});
                            return Consume{
                                .reserved_1 = reserved_1,
                                .queue = queue,
                                .consumer_tag = consumer_tag,
                                .no_local = no_local,
                                .no_ack = no_ack,
                                .exclusive = exclusive,
                                .no_wait = no_wait,
                                .arguments = arguments,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // consume-ok

    pub const ConsumeOk = struct {
        consumer_tag: []const u8,
    };
    pub const CONSUME_OK_METHOD = 21;
    pub fn consumeOkAsync(
        conn: *Connector,
        consumer_tag: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.CONSUME_OK_METHOD);
        conn.tx_buffer.writeShortString(consumer_tag);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Consume_ok ->", .{conn.channel});
    }

    // consume_ok
    pub fn awaitConsumeOk(conn: *Connector) !ConsumeOk {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == CONSUME_OK_METHOD) {
                            const consumer_tag = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Consume_ok", .{conn.channel});
                            return ConsumeOk{
                                .consumer_tag = consumer_tag,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // cancel

    pub const Cancel = struct {
        consumer_tag: []const u8,
        no_wait: bool,
    };
    pub const CANCEL_METHOD = 30;
    pub fn cancelSync(
        conn: *Connector,
        consumer_tag: []const u8,
        no_wait: bool,
    ) !CancelOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, CANCEL_METHOD);
        conn.tx_buffer.writeShortString(consumer_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_wait) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Cancel ->", .{conn.channel});
        return awaitCancelOk(conn);
    }

    // cancel
    pub fn awaitCancel(conn: *Connector) !Cancel {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == CANCEL_METHOD) {
                            const consumer_tag = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Cancel", .{conn.channel});
                            return Cancel{
                                .consumer_tag = consumer_tag,
                                .no_wait = no_wait,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // cancel-ok

    pub const CancelOk = struct {
        consumer_tag: []const u8,
    };
    pub const CANCEL_OK_METHOD = 31;
    pub fn cancelOkAsync(
        conn: *Connector,
        consumer_tag: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.CANCEL_OK_METHOD);
        conn.tx_buffer.writeShortString(consumer_tag);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Cancel_ok ->", .{conn.channel});
    }

    // cancel_ok
    pub fn awaitCancelOk(conn: *Connector) !CancelOk {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == CANCEL_OK_METHOD) {
                            const consumer_tag = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Cancel_ok", .{conn.channel});
                            return CancelOk{
                                .consumer_tag = consumer_tag,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // publish

    pub const Publish = struct {
        reserved_1: u16,
        exchange: []const u8,
        routing_key: []const u8,
        mandatory: bool,
        immediate: bool,
    };
    pub const PUBLISH_METHOD = 40;
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Publish ->", .{conn.channel});
    }

    // publish
    pub fn awaitPublish(conn: *Connector) !Publish {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == PUBLISH_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const mandatory = if (bitset0 & (1 << 0) == 0) true else false;
                            const immediate = if (bitset0 & (1 << 1) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Publish", .{conn.channel});
                            return Publish{
                                .reserved_1 = reserved_1,
                                .exchange = exchange,
                                .routing_key = routing_key,
                                .mandatory = mandatory,
                                .immediate = immediate,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // return

    pub const Return = struct {
        reply_code: u16,
        reply_text: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
    };
    pub const RETURN_METHOD = 50;
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Return ->", .{conn.channel});
    }

    // @"return"
    pub fn awaitReturn(conn: *Connector) !Return {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == RETURN_METHOD) {
                            const reply_code = conn.rx_buffer.readU16();
                            const reply_text = conn.rx_buffer.readShortString();
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Return", .{conn.channel});
                            return Return{
                                .reply_code = reply_code,
                                .reply_text = reply_text,
                                .exchange = exchange,
                                .routing_key = routing_key,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // deliver

    pub const Deliver = struct {
        consumer_tag: []const u8,
        delivery_tag: u64,
        redelivered: bool,
        exchange: []const u8,
        routing_key: []const u8,
    };
    pub const DELIVER_METHOD = 60;
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Deliver ->", .{conn.channel});
    }

    // deliver
    pub fn awaitDeliver(conn: *Connector) !Deliver {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == DELIVER_METHOD) {
                            const consumer_tag = conn.rx_buffer.readShortString();
                            const delivery_tag = conn.rx_buffer.readU64();
                            const bitset0 = conn.rx_buffer.readU8();
                            const redelivered = if (bitset0 & (1 << 0) == 0) true else false;
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Deliver", .{conn.channel});
                            return Deliver{
                                .consumer_tag = consumer_tag,
                                .delivery_tag = delivery_tag,
                                .redelivered = redelivered,
                                .exchange = exchange,
                                .routing_key = routing_key,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // get

    pub const Get = struct {
        reserved_1: u16,
        queue: []const u8,
        no_ack: bool,
    };
    pub const GET_METHOD = 70;
    pub fn getSync(
        conn: *Connector,
        queue: []const u8,
        no_ack: bool,
    ) !GetEmpty {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, GET_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_ack) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Get ->", .{conn.channel});
        return awaitGetEmpty(conn);
    }

    // get
    pub fn awaitGet(conn: *Connector) !Get {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == GET_METHOD) {
                            const reserved_1 = conn.rx_buffer.readU16();
                            const queue = conn.rx_buffer.readShortString();
                            const bitset0 = conn.rx_buffer.readU8();
                            const no_ack = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Get", .{conn.channel});
                            return Get{
                                .reserved_1 = reserved_1,
                                .queue = queue,
                                .no_ack = no_ack,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // get-ok

    pub const GetOk = struct {
        delivery_tag: u64,
        redelivered: bool,
        exchange: []const u8,
        routing_key: []const u8,
        message_count: u32,
    };
    pub const GET_OK_METHOD = 71;
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Get_ok ->", .{conn.channel});
    }

    // get_ok
    pub fn awaitGetOk(conn: *Connector) !GetOk {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == GET_OK_METHOD) {
                            const delivery_tag = conn.rx_buffer.readU64();
                            const bitset0 = conn.rx_buffer.readU8();
                            const redelivered = if (bitset0 & (1 << 0) == 0) true else false;
                            const exchange = conn.rx_buffer.readShortString();
                            const routing_key = conn.rx_buffer.readShortString();
                            const message_count = conn.rx_buffer.readU32();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Get_ok", .{conn.channel});
                            return GetOk{
                                .delivery_tag = delivery_tag,
                                .redelivered = redelivered,
                                .exchange = exchange,
                                .routing_key = routing_key,
                                .message_count = message_count,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // get-empty

    pub const GetEmpty = struct {
        reserved_1: []const u8,
    };
    pub const GET_EMPTY_METHOD = 72;
    pub fn getEmptyAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.GET_EMPTY_METHOD);
        const reserved_1 = "";
        conn.tx_buffer.writeShortString(reserved_1);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Get_empty ->", .{conn.channel});
    }

    // get_empty
    pub fn awaitGetEmpty(conn: *Connector) !GetEmpty {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == GET_EMPTY_METHOD) {
                            const reserved_1 = conn.rx_buffer.readShortString();
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Get_empty", .{conn.channel});
                            return GetEmpty{
                                .reserved_1 = reserved_1,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // ack

    pub const Ack = struct {
        delivery_tag: u64,
        multiple: bool,
    };
    pub const ACK_METHOD = 80;
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Ack ->", .{conn.channel});
    }

    // ack
    pub fn awaitAck(conn: *Connector) !Ack {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == ACK_METHOD) {
                            const delivery_tag = conn.rx_buffer.readU64();
                            const bitset0 = conn.rx_buffer.readU8();
                            const multiple = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Ack", .{conn.channel});
                            return Ack{
                                .delivery_tag = delivery_tag,
                                .multiple = multiple,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // reject

    pub const Reject = struct {
        delivery_tag: u64,
        requeue: bool,
    };
    pub const REJECT_METHOD = 90;
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Reject ->", .{conn.channel});
    }

    // reject
    pub fn awaitReject(conn: *Connector) !Reject {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == REJECT_METHOD) {
                            const delivery_tag = conn.rx_buffer.readU64();
                            const bitset0 = conn.rx_buffer.readU8();
                            const requeue = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Reject", .{conn.channel});
                            return Reject{
                                .delivery_tag = delivery_tag,
                                .requeue = requeue,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // recover-async

    pub const RecoverAsync = struct {
        requeue: bool,
    };
    pub const RECOVER_ASYNC_METHOD = 100;
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Recover_async ->", .{conn.channel});
    }

    // recover_async
    pub fn awaitRecoverAsync(conn: *Connector) !RecoverAsync {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == RECOVER_ASYNC_METHOD) {
                            const bitset0 = conn.rx_buffer.readU8();
                            const requeue = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Recover_async", .{conn.channel});
                            return RecoverAsync{
                                .requeue = requeue,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // recover

    pub const Recover = struct {
        requeue: bool,
    };
    pub const RECOVER_METHOD = 110;
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
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Recover ->", .{conn.channel});
    }

    // recover
    pub fn awaitRecover(conn: *Connector) !Recover {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == RECOVER_METHOD) {
                            const bitset0 = conn.rx_buffer.readU8();
                            const requeue = if (bitset0 & (1 << 0) == 0) true else false;
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Recover", .{conn.channel});
                            return Recover{
                                .requeue = requeue,
                            };
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // recover-ok

    pub const RecoverOk = struct {};
    pub const RECOVER_OK_METHOD = 111;
    pub fn recoverOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.RECOVER_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Basic@{}.Recover_ok ->", .{conn.channel});
    }

    // recover_ok
    pub fn awaitRecoverOk(conn: *Connector) !RecoverOk {
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
                        if (method_header.class == BASIC_CLASS and method_header.method == RECOVER_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Basic@{}.Recover_ok", .{conn.channel});
                            return RecoverOk{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

// tx
pub const Tx = struct {
    pub const TX_CLASS = 90;

    // select

    pub const Select = struct {};
    pub const SELECT_METHOD = 10;
    pub fn selectSync(
        conn: *Connector,
    ) !SelectOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, SELECT_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Tx@{}.Select ->", .{conn.channel});
        return awaitSelectOk(conn);
    }

    // select
    pub fn awaitSelect(conn: *Connector) !Select {
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
                        if (method_header.class == TX_CLASS and method_header.method == SELECT_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Tx@{}.Select", .{conn.channel});
                            return Select{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // select-ok

    pub const SelectOk = struct {};
    pub const SELECT_OK_METHOD = 11;
    pub fn selectOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.SELECT_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Tx@{}.Select_ok ->", .{conn.channel});
    }

    // select_ok
    pub fn awaitSelectOk(conn: *Connector) !SelectOk {
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
                        if (method_header.class == TX_CLASS and method_header.method == SELECT_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Tx@{}.Select_ok", .{conn.channel});
                            return SelectOk{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // commit

    pub const Commit = struct {};
    pub const COMMIT_METHOD = 20;
    pub fn commitSync(
        conn: *Connector,
    ) !CommitOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, COMMIT_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Tx@{}.Commit ->", .{conn.channel});
        return awaitCommitOk(conn);
    }

    // commit
    pub fn awaitCommit(conn: *Connector) !Commit {
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
                        if (method_header.class == TX_CLASS and method_header.method == COMMIT_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Tx@{}.Commit", .{conn.channel});
                            return Commit{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // commit-ok

    pub const CommitOk = struct {};
    pub const COMMIT_OK_METHOD = 21;
    pub fn commitOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.COMMIT_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Tx@{}.Commit_ok ->", .{conn.channel});
    }

    // commit_ok
    pub fn awaitCommitOk(conn: *Connector) !CommitOk {
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
                        if (method_header.class == TX_CLASS and method_header.method == COMMIT_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Tx@{}.Commit_ok", .{conn.channel});
                            return CommitOk{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // rollback

    pub const Rollback = struct {};
    pub const ROLLBACK_METHOD = 30;
    pub fn rollbackSync(
        conn: *Connector,
    ) !RollbackOk {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, ROLLBACK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Tx@{}.Rollback ->", .{conn.channel});
        return awaitRollbackOk(conn);
    }

    // rollback
    pub fn awaitRollback(conn: *Connector) !Rollback {
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
                        if (method_header.class == TX_CLASS and method_header.method == ROLLBACK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Tx@{}.Rollback", .{conn.channel});
                            return Rollback{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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

    // rollback-ok

    pub const RollbackOk = struct {};
    pub const ROLLBACK_OK_METHOD = 31;
    pub fn rollbackOkAsync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.ROLLBACK_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        std.log.debug("Tx@{}.Rollback_ok ->", .{conn.channel});
    }

    // rollback_ok
    pub fn awaitRollbackOk(conn: *Connector) !RollbackOk {
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
                        if (method_header.class == TX_CLASS and method_header.method == ROLLBACK_OK_METHOD) {
                            try conn.rx_buffer.readEOF();
                            std.log.debug("\t<- Tx@{}.Rollback_ok", .{conn.channel});
                            return RollbackOk{};
                        } else {
                            if (method_header.class == 10 and method_header.method == 50) {
                                try Connection.closeOkAsync(conn);
                                return error.ConnectionClose;
                            }
                            if (method_header.class == 20 and method_header.method == 40) {
                                try Channel.closeOkAsync(conn);
                                return error.ChannelClose;
                            }
                            return error.ImplementAsyncHandle;
                        }
                    },
                    .Heartbeat => {
                        std.log.debug("Got heartbeat", .{});
                        try conn.rx_buffer.readEOF();
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
