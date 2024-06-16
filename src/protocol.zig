const std = @import("std");
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
        pub const CLASS = 10;
        pub const METHOD = 10;

        version_major: u8,
        version_minor: u8,
        server_properties: Table,
        mechanisms: []const u8,
        locales: []const u8,

        pub fn read(connector: *Connector) !Start {
            const version_major = connector.rx_buffer.readU8();
            const version_minor = connector.rx_buffer.readU8();
            const server_properties = connector.rx_buffer.readTable();
            const mechanisms = connector.rx_buffer.readLongString();
            const locales = connector.rx_buffer.readLongString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Start", .{connector.channel});
            return Start{
                .version_major = version_major,
                .version_minor = version_minor,
                .server_properties = server_properties,
                .mechanisms = mechanisms,
                .locales = locales,
            };
        }
    };
    pub const START_METHOD = 10;
    pub fn startSync(
        connector: *Connector,
        version_major: u8,
        version_minor: u8,
        server_properties: ?*Table,
        mechanisms: []const u8,
        locales: []const u8,
    ) !StartOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, START_METHOD);
        connector.tx_buffer.writeU8(version_major);
        connector.tx_buffer.writeU8(version_minor);
        connector.tx_buffer.writeTable(server_properties);
        connector.tx_buffer.writeLongString(mechanisms);
        connector.tx_buffer.writeLongString(locales);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Start ->", .{connector.channel});
        return awaitStartOk(connector);
    }

    // start
    pub fn awaitStart(connector: *Connector) !Start {
        return connector.awaitMethod(Start);
    }

    // start-ok

    pub const StartOk = struct {
        pub const CLASS = 10;
        pub const METHOD = 11;

        client_properties: Table,
        mechanism: []const u8,
        response: []const u8,
        locale: []const u8,

        pub fn read(connector: *Connector) !StartOk {
            const client_properties = connector.rx_buffer.readTable();
            const mechanism = connector.rx_buffer.readShortString();
            const response = connector.rx_buffer.readLongString();
            const locale = connector.rx_buffer.readShortString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Start_ok", .{connector.channel});
            return StartOk{
                .client_properties = client_properties,
                .mechanism = mechanism,
                .response = response,
                .locale = locale,
            };
        }
    };
    pub const START_OK_METHOD = 11;
    pub fn startOkAsync(
        connector: *Connector,
        client_properties: ?*Table,
        mechanism: []const u8,
        response: []const u8,
        locale: []const u8,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.START_OK_METHOD);
        connector.tx_buffer.writeTable(client_properties);
        connector.tx_buffer.writeShortString(mechanism);
        connector.tx_buffer.writeLongString(response);
        connector.tx_buffer.writeShortString(locale);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Start_ok ->", .{connector.channel});
    }

    // start_ok
    pub fn awaitStartOk(connector: *Connector) !StartOk {
        return connector.awaitMethod(StartOk);
    }

    // secure

    pub const Secure = struct {
        pub const CLASS = 10;
        pub const METHOD = 20;

        challenge: []const u8,

        pub fn read(connector: *Connector) !Secure {
            const challenge = connector.rx_buffer.readLongString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Secure", .{connector.channel});
            return Secure{
                .challenge = challenge,
            };
        }
    };
    pub const SECURE_METHOD = 20;
    pub fn secureSync(
        connector: *Connector,
        challenge: []const u8,
    ) !SecureOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, SECURE_METHOD);
        connector.tx_buffer.writeLongString(challenge);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Secure ->", .{connector.channel});
        return awaitSecureOk(connector);
    }

    // secure
    pub fn awaitSecure(connector: *Connector) !Secure {
        return connector.awaitMethod(Secure);
    }

    // secure-ok

    pub const SecureOk = struct {
        pub const CLASS = 10;
        pub const METHOD = 21;

        response: []const u8,

        pub fn read(connector: *Connector) !SecureOk {
            const response = connector.rx_buffer.readLongString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Secure_ok", .{connector.channel});
            return SecureOk{
                .response = response,
            };
        }
    };
    pub const SECURE_OK_METHOD = 21;
    pub fn secureOkAsync(
        connector: *Connector,
        response: []const u8,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.SECURE_OK_METHOD);
        connector.tx_buffer.writeLongString(response);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Secure_ok ->", .{connector.channel});
    }

    // secure_ok
    pub fn awaitSecureOk(connector: *Connector) !SecureOk {
        return connector.awaitMethod(SecureOk);
    }

    // tune

    pub const Tune = struct {
        pub const CLASS = 10;
        pub const METHOD = 30;

        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,

        pub fn read(connector: *Connector) !Tune {
            const channel_max = connector.rx_buffer.readU16();
            const frame_max = connector.rx_buffer.readU32();
            const heartbeat = connector.rx_buffer.readU16();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Tune", .{connector.channel});
            return Tune{
                .channel_max = channel_max,
                .frame_max = frame_max,
                .heartbeat = heartbeat,
            };
        }
    };
    pub const TUNE_METHOD = 30;
    pub fn tuneSync(
        connector: *Connector,
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    ) !TuneOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, TUNE_METHOD);
        connector.tx_buffer.writeU16(channel_max);
        connector.tx_buffer.writeU32(frame_max);
        connector.tx_buffer.writeU16(heartbeat);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Tune ->", .{connector.channel});
        return awaitTuneOk(connector);
    }

    // tune
    pub fn awaitTune(connector: *Connector) !Tune {
        return connector.awaitMethod(Tune);
    }

    // tune-ok

    pub const TuneOk = struct {
        pub const CLASS = 10;
        pub const METHOD = 31;

        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,

        pub fn read(connector: *Connector) !TuneOk {
            const channel_max = connector.rx_buffer.readU16();
            const frame_max = connector.rx_buffer.readU32();
            const heartbeat = connector.rx_buffer.readU16();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Tune_ok", .{connector.channel});
            return TuneOk{
                .channel_max = channel_max,
                .frame_max = frame_max,
                .heartbeat = heartbeat,
            };
        }
    };
    pub const TUNE_OK_METHOD = 31;
    pub fn tuneOkAsync(
        connector: *Connector,
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.TUNE_OK_METHOD);
        connector.tx_buffer.writeU16(channel_max);
        connector.tx_buffer.writeU32(frame_max);
        connector.tx_buffer.writeU16(heartbeat);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Tune_ok ->", .{connector.channel});
    }

    // tune_ok
    pub fn awaitTuneOk(connector: *Connector) !TuneOk {
        return connector.awaitMethod(TuneOk);
    }

    // open

    pub const Open = struct {
        pub const CLASS = 10;
        pub const METHOD = 40;

        virtual_host: []const u8,
        reserved_1: []const u8,
        reserved_2: bool,

        pub fn read(connector: *Connector) !Open {
            const virtual_host = connector.rx_buffer.readShortString();
            const reserved_1 = connector.rx_buffer.readShortString();
            const bitset0 = connector.rx_buffer.readU8();
            const reserved_2 = if (bitset0 & (1 << 0) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Open", .{connector.channel});
            return Open{
                .virtual_host = virtual_host,
                .reserved_1 = reserved_1,
                .reserved_2 = reserved_2,
            };
        }
    };
    pub const OPEN_METHOD = 40;
    pub fn openSync(
        connector: *Connector,
        virtual_host: []const u8,
    ) !OpenOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, OPEN_METHOD);
        connector.tx_buffer.writeShortString(virtual_host);
        const reserved_1 = "";
        connector.tx_buffer.writeShortString(reserved_1);
        const reserved_2 = false;
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (reserved_2) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Open ->", .{connector.channel});
        return awaitOpenOk(connector);
    }

    // open
    pub fn awaitOpen(connector: *Connector) !Open {
        return connector.awaitMethod(Open);
    }

    // open-ok

    pub const OpenOk = struct {
        pub const CLASS = 10;
        pub const METHOD = 41;

        reserved_1: []const u8,

        pub fn read(connector: *Connector) !OpenOk {
            const reserved_1 = connector.rx_buffer.readShortString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Open_ok", .{connector.channel});
            return OpenOk{
                .reserved_1 = reserved_1,
            };
        }
    };
    pub const OPEN_OK_METHOD = 41;
    pub fn openOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.OPEN_OK_METHOD);
        const reserved_1 = "";
        connector.tx_buffer.writeShortString(reserved_1);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Open_ok ->", .{connector.channel});
    }

    // open_ok
    pub fn awaitOpenOk(connector: *Connector) !OpenOk {
        return connector.awaitMethod(OpenOk);
    }

    // close

    pub const Close = struct {
        pub const CLASS = 10;
        pub const METHOD = 50;

        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,

        pub fn read(connector: *Connector) !Close {
            const reply_code = connector.rx_buffer.readU16();
            const reply_text = connector.rx_buffer.readShortString();
            const class_id = connector.rx_buffer.readU16();
            const method_id = connector.rx_buffer.readU16();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Close", .{connector.channel});
            return Close{
                .reply_code = reply_code,
                .reply_text = reply_text,
                .class_id = class_id,
                .method_id = method_id,
            };
        }
    };
    pub const CLOSE_METHOD = 50;
    pub fn closeSync(
        connector: *Connector,
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    ) !CloseOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, CLOSE_METHOD);
        connector.tx_buffer.writeU16(reply_code);
        connector.tx_buffer.writeShortString(reply_text);
        connector.tx_buffer.writeU16(class_id);
        connector.tx_buffer.writeU16(method_id);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Close ->", .{connector.channel});
        return awaitCloseOk(connector);
    }

    // close
    pub fn awaitClose(connector: *Connector) !Close {
        return connector.awaitMethod(Close);
    }

    // close-ok

    pub const CloseOk = struct {
        pub const CLASS = 10;
        pub const METHOD = 51;

        pub fn read(connector: *Connector) !CloseOk {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Close_ok", .{connector.channel});
            return CloseOk{};
        }
    };
    pub const CLOSE_OK_METHOD = 51;
    pub fn closeOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.CLOSE_OK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Close_ok ->", .{connector.channel});
    }

    // close_ok
    pub fn awaitCloseOk(connector: *Connector) !CloseOk {
        return connector.awaitMethod(CloseOk);
    }

    // blocked

    pub const Blocked = struct {
        pub const CLASS = 10;
        pub const METHOD = 60;

        reason: []const u8,

        pub fn read(connector: *Connector) !Blocked {
            const reason = connector.rx_buffer.readShortString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Blocked", .{connector.channel});
            return Blocked{
                .reason = reason,
            };
        }
    };
    pub const BLOCKED_METHOD = 60;
    pub fn blockedAsync(
        connector: *Connector,
        reason: []const u8,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.BLOCKED_METHOD);
        connector.tx_buffer.writeShortString(reason);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Blocked ->", .{connector.channel});
    }

    // blocked
    pub fn awaitBlocked(connector: *Connector) !Blocked {
        return connector.awaitMethod(Blocked);
    }

    // unblocked

    pub const Unblocked = struct {
        pub const CLASS = 10;
        pub const METHOD = 61;

        pub fn read(connector: *Connector) !Unblocked {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Connection@{any}.Unblocked", .{connector.channel});
            return Unblocked{};
        }
    };
    pub const UNBLOCKED_METHOD = 61;
    pub fn unblockedAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.UNBLOCKED_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Connection@{any}.Unblocked ->", .{connector.channel});
    }

    // unblocked
    pub fn awaitUnblocked(connector: *Connector) !Unblocked {
        return connector.awaitMethod(Unblocked);
    }
};

// channel
pub const Channel = struct {
    pub const CHANNEL_CLASS = 20;

    // open

    pub const Open = struct {
        pub const CLASS = 20;
        pub const METHOD = 10;

        reserved_1: []const u8,

        pub fn read(connector: *Connector) !Open {
            const reserved_1 = connector.rx_buffer.readShortString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Channel@{any}.Open", .{connector.channel});
            return Open{
                .reserved_1 = reserved_1,
            };
        }
    };
    pub const OPEN_METHOD = 10;
    pub fn openSync(
        connector: *Connector,
    ) !OpenOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CHANNEL_CLASS, OPEN_METHOD);
        const reserved_1 = "";
        connector.tx_buffer.writeShortString(reserved_1);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Channel@{any}.Open ->", .{connector.channel});
        return awaitOpenOk(connector);
    }

    // open
    pub fn awaitOpen(connector: *Connector) !Open {
        return connector.awaitMethod(Open);
    }

    // open-ok

    pub const OpenOk = struct {
        pub const CLASS = 20;
        pub const METHOD = 11;

        reserved_1: []const u8,

        pub fn read(connector: *Connector) !OpenOk {
            const reserved_1 = connector.rx_buffer.readLongString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Channel@{any}.Open_ok", .{connector.channel});
            return OpenOk{
                .reserved_1 = reserved_1,
            };
        }
    };
    pub const OPEN_OK_METHOD = 11;
    pub fn openOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.OPEN_OK_METHOD);
        const reserved_1 = "";
        connector.tx_buffer.writeLongString(reserved_1);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Channel@{any}.Open_ok ->", .{connector.channel});
    }

    // open_ok
    pub fn awaitOpenOk(connector: *Connector) !OpenOk {
        return connector.awaitMethod(OpenOk);
    }

    // flow

    pub const Flow = struct {
        pub const CLASS = 20;
        pub const METHOD = 20;

        active: bool,

        pub fn read(connector: *Connector) !Flow {
            const bitset0 = connector.rx_buffer.readU8();
            const active = if (bitset0 & (1 << 0) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Channel@{any}.Flow", .{connector.channel});
            return Flow{
                .active = active,
            };
        }
    };
    pub const FLOW_METHOD = 20;
    pub fn flowSync(
        connector: *Connector,
        active: bool,
    ) !FlowOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CHANNEL_CLASS, FLOW_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (active) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Channel@{any}.Flow ->", .{connector.channel});
        return awaitFlowOk(connector);
    }

    // flow
    pub fn awaitFlow(connector: *Connector) !Flow {
        return connector.awaitMethod(Flow);
    }

    // flow-ok

    pub const FlowOk = struct {
        pub const CLASS = 20;
        pub const METHOD = 21;

        active: bool,

        pub fn read(connector: *Connector) !FlowOk {
            const bitset0 = connector.rx_buffer.readU8();
            const active = if (bitset0 & (1 << 0) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Channel@{any}.Flow_ok", .{connector.channel});
            return FlowOk{
                .active = active,
            };
        }
    };
    pub const FLOW_OK_METHOD = 21;
    pub fn flowOkAsync(
        connector: *Connector,
        active: bool,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.FLOW_OK_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (active) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Channel@{any}.Flow_ok ->", .{connector.channel});
    }

    // flow_ok
    pub fn awaitFlowOk(connector: *Connector) !FlowOk {
        return connector.awaitMethod(FlowOk);
    }

    // close

    pub const Close = struct {
        pub const CLASS = 20;
        pub const METHOD = 40;

        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,

        pub fn read(connector: *Connector) !Close {
            const reply_code = connector.rx_buffer.readU16();
            const reply_text = connector.rx_buffer.readShortString();
            const class_id = connector.rx_buffer.readU16();
            const method_id = connector.rx_buffer.readU16();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Channel@{any}.Close", .{connector.channel});
            return Close{
                .reply_code = reply_code,
                .reply_text = reply_text,
                .class_id = class_id,
                .method_id = method_id,
            };
        }
    };
    pub const CLOSE_METHOD = 40;
    pub fn closeSync(
        connector: *Connector,
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    ) !CloseOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CHANNEL_CLASS, CLOSE_METHOD);
        connector.tx_buffer.writeU16(reply_code);
        connector.tx_buffer.writeShortString(reply_text);
        connector.tx_buffer.writeU16(class_id);
        connector.tx_buffer.writeU16(method_id);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Channel@{any}.Close ->", .{connector.channel});
        return awaitCloseOk(connector);
    }

    // close
    pub fn awaitClose(connector: *Connector) !Close {
        return connector.awaitMethod(Close);
    }

    // close-ok

    pub const CloseOk = struct {
        pub const CLASS = 20;
        pub const METHOD = 41;

        pub fn read(connector: *Connector) !CloseOk {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Channel@{any}.Close_ok", .{connector.channel});
            return CloseOk{};
        }
    };
    pub const CLOSE_OK_METHOD = 41;
    pub fn closeOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.CLOSE_OK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Channel@{any}.Close_ok ->", .{connector.channel});
    }

    // close_ok
    pub fn awaitCloseOk(connector: *Connector) !CloseOk {
        return connector.awaitMethod(CloseOk);
    }
};

// exchange
pub const Exchange = struct {
    pub const EXCHANGE_CLASS = 40;

    // declare

    pub const Declare = struct {
        pub const CLASS = 40;
        pub const METHOD = 10;

        reserved_1: u16,
        exchange: []const u8,
        tipe: []const u8,
        passive: bool,
        durable: bool,
        reserved_2: bool,
        reserved_3: bool,
        no_wait: bool,
        arguments: Table,

        pub fn read(connector: *Connector) !Declare {
            const reserved_1 = connector.rx_buffer.readU16();
            const exchange = connector.rx_buffer.readShortString();
            const tipe = connector.rx_buffer.readShortString();
            const bitset0 = connector.rx_buffer.readU8();
            const passive = if (bitset0 & (1 << 0) == 0) true else false;
            const durable = if (bitset0 & (1 << 1) == 0) true else false;
            const reserved_2 = if (bitset0 & (1 << 2) == 0) true else false;
            const reserved_3 = if (bitset0 & (1 << 3) == 0) true else false;
            const no_wait = if (bitset0 & (1 << 4) == 0) true else false;
            const arguments = connector.rx_buffer.readTable();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Exchange@{any}.Declare", .{connector.channel});
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
        }
    };
    pub const DECLARE_METHOD = 10;
    pub fn declareSync(
        connector: *Connector,
        exchange: []const u8,
        tipe: []const u8,
        passive: bool,
        durable: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) !DeclareOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, DECLARE_METHOD);
        const reserved_1 = 0;
        connector.tx_buffer.writeU16(reserved_1);
        connector.tx_buffer.writeShortString(exchange);
        connector.tx_buffer.writeShortString(tipe);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (passive) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (durable) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        const reserved_2 = false;
        if (reserved_2) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        const reserved_3 = false;
        if (reserved_3) bitset0 |= (_bit << 3) else bitset0 &= ~(_bit << 3);
        if (no_wait) bitset0 |= (_bit << 4) else bitset0 &= ~(_bit << 4);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.writeTable(arguments);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Exchange@{any}.Declare ->", .{connector.channel});
        return awaitDeclareOk(connector);
    }

    // declare
    pub fn awaitDeclare(connector: *Connector) !Declare {
        return connector.awaitMethod(Declare);
    }

    // declare-ok

    pub const DeclareOk = struct {
        pub const CLASS = 40;
        pub const METHOD = 11;

        pub fn read(connector: *Connector) !DeclareOk {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Exchange@{any}.Declare_ok", .{connector.channel});
            return DeclareOk{};
        }
    };
    pub const DECLARE_OK_METHOD = 11;
    pub fn declareOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, Exchange.DECLARE_OK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Exchange@{any}.Declare_ok ->", .{connector.channel});
    }

    // declare_ok
    pub fn awaitDeclareOk(connector: *Connector) !DeclareOk {
        return connector.awaitMethod(DeclareOk);
    }

    // delete

    pub const Delete = struct {
        pub const CLASS = 40;
        pub const METHOD = 20;

        reserved_1: u16,
        exchange: []const u8,
        if_unused: bool,
        no_wait: bool,

        pub fn read(connector: *Connector) !Delete {
            const reserved_1 = connector.rx_buffer.readU16();
            const exchange = connector.rx_buffer.readShortString();
            const bitset0 = connector.rx_buffer.readU8();
            const if_unused = if (bitset0 & (1 << 0) == 0) true else false;
            const no_wait = if (bitset0 & (1 << 1) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Exchange@{any}.Delete", .{connector.channel});
            return Delete{
                .reserved_1 = reserved_1,
                .exchange = exchange,
                .if_unused = if_unused,
                .no_wait = no_wait,
            };
        }
    };
    pub const DELETE_METHOD = 20;
    pub fn deleteSync(
        connector: *Connector,
        exchange: []const u8,
        if_unused: bool,
        no_wait: bool,
    ) !DeleteOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, DELETE_METHOD);
        const reserved_1 = 0;
        connector.tx_buffer.writeU16(reserved_1);
        connector.tx_buffer.writeShortString(exchange);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (if_unused) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (no_wait) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Exchange@{any}.Delete ->", .{connector.channel});
        return awaitDeleteOk(connector);
    }

    // delete
    pub fn awaitDelete(connector: *Connector) !Delete {
        return connector.awaitMethod(Delete);
    }

    // delete-ok

    pub const DeleteOk = struct {
        pub const CLASS = 40;
        pub const METHOD = 21;

        pub fn read(connector: *Connector) !DeleteOk {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Exchange@{any}.Delete_ok", .{connector.channel});
            return DeleteOk{};
        }
    };
    pub const DELETE_OK_METHOD = 21;
    pub fn deleteOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, Exchange.DELETE_OK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Exchange@{any}.Delete_ok ->", .{connector.channel});
    }

    // delete_ok
    pub fn awaitDeleteOk(connector: *Connector) !DeleteOk {
        return connector.awaitMethod(DeleteOk);
    }
};

// queue
pub const Queue = struct {
    pub const QUEUE_CLASS = 50;

    // declare

    pub const Declare = struct {
        pub const CLASS = 50;
        pub const METHOD = 10;

        reserved_1: u16,
        queue: []const u8,
        passive: bool,
        durable: bool,
        exclusive: bool,
        auto_delete: bool,
        no_wait: bool,
        arguments: Table,

        pub fn read(connector: *Connector) !Declare {
            const reserved_1 = connector.rx_buffer.readU16();
            const queue = connector.rx_buffer.readShortString();
            const bitset0 = connector.rx_buffer.readU8();
            const passive = if (bitset0 & (1 << 0) == 0) true else false;
            const durable = if (bitset0 & (1 << 1) == 0) true else false;
            const exclusive = if (bitset0 & (1 << 2) == 0) true else false;
            const auto_delete = if (bitset0 & (1 << 3) == 0) true else false;
            const no_wait = if (bitset0 & (1 << 4) == 0) true else false;
            const arguments = connector.rx_buffer.readTable();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Queue@{any}.Declare", .{connector.channel});
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
        }
    };
    pub const DECLARE_METHOD = 10;
    pub fn declareSync(
        connector: *Connector,
        queue: []const u8,
        passive: bool,
        durable: bool,
        exclusive: bool,
        auto_delete: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) !DeclareOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(QUEUE_CLASS, DECLARE_METHOD);
        const reserved_1 = 0;
        connector.tx_buffer.writeU16(reserved_1);
        connector.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (passive) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (durable) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        if (exclusive) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        if (auto_delete) bitset0 |= (_bit << 3) else bitset0 &= ~(_bit << 3);
        if (no_wait) bitset0 |= (_bit << 4) else bitset0 &= ~(_bit << 4);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.writeTable(arguments);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Queue@{any}.Declare ->", .{connector.channel});
        return awaitDeclareOk(connector);
    }

    // declare
    pub fn awaitDeclare(connector: *Connector) !Declare {
        return connector.awaitMethod(Declare);
    }

    // declare-ok

    pub const DeclareOk = struct {
        pub const CLASS = 50;
        pub const METHOD = 11;

        queue: []const u8,
        message_count: u32,
        consumer_count: u32,

        pub fn read(connector: *Connector) !DeclareOk {
            const queue = connector.rx_buffer.readShortString();
            const message_count = connector.rx_buffer.readU32();
            const consumer_count = connector.rx_buffer.readU32();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Queue@{any}.Declare_ok", .{connector.channel});
            return DeclareOk{
                .queue = queue,
                .message_count = message_count,
                .consumer_count = consumer_count,
            };
        }
    };
    pub const DECLARE_OK_METHOD = 11;
    pub fn declareOkAsync(
        connector: *Connector,
        queue: []const u8,
        message_count: u32,
        consumer_count: u32,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.DECLARE_OK_METHOD);
        connector.tx_buffer.writeShortString(queue);
        connector.tx_buffer.writeU32(message_count);
        connector.tx_buffer.writeU32(consumer_count);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Queue@{any}.Declare_ok ->", .{connector.channel});
    }

    // declare_ok
    pub fn awaitDeclareOk(connector: *Connector) !DeclareOk {
        return connector.awaitMethod(DeclareOk);
    }

    // bind

    pub const Bind = struct {
        pub const CLASS = 50;
        pub const METHOD = 20;

        reserved_1: u16,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        no_wait: bool,
        arguments: Table,

        pub fn read(connector: *Connector) !Bind {
            const reserved_1 = connector.rx_buffer.readU16();
            const queue = connector.rx_buffer.readShortString();
            const exchange = connector.rx_buffer.readShortString();
            const routing_key = connector.rx_buffer.readShortString();
            const bitset0 = connector.rx_buffer.readU8();
            const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
            const arguments = connector.rx_buffer.readTable();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Queue@{any}.Bind", .{connector.channel});
            return Bind{
                .reserved_1 = reserved_1,
                .queue = queue,
                .exchange = exchange,
                .routing_key = routing_key,
                .no_wait = no_wait,
                .arguments = arguments,
            };
        }
    };
    pub const BIND_METHOD = 20;
    pub fn bindSync(
        connector: *Connector,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        no_wait: bool,
        arguments: ?*Table,
    ) !BindOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(QUEUE_CLASS, BIND_METHOD);
        const reserved_1 = 0;
        connector.tx_buffer.writeU16(reserved_1);
        connector.tx_buffer.writeShortString(queue);
        connector.tx_buffer.writeShortString(exchange);
        connector.tx_buffer.writeShortString(routing_key);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_wait) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.writeTable(arguments);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Queue@{any}.Bind ->", .{connector.channel});
        return awaitBindOk(connector);
    }

    // bind
    pub fn awaitBind(connector: *Connector) !Bind {
        return connector.awaitMethod(Bind);
    }

    // bind-ok

    pub const BindOk = struct {
        pub const CLASS = 50;
        pub const METHOD = 21;

        pub fn read(connector: *Connector) !BindOk {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Queue@{any}.Bind_ok", .{connector.channel});
            return BindOk{};
        }
    };
    pub const BIND_OK_METHOD = 21;
    pub fn bindOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.BIND_OK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Queue@{any}.Bind_ok ->", .{connector.channel});
    }

    // bind_ok
    pub fn awaitBindOk(connector: *Connector) !BindOk {
        return connector.awaitMethod(BindOk);
    }

    // unbind

    pub const Unbind = struct {
        pub const CLASS = 50;
        pub const METHOD = 50;

        reserved_1: u16,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        arguments: Table,

        pub fn read(connector: *Connector) !Unbind {
            const reserved_1 = connector.rx_buffer.readU16();
            const queue = connector.rx_buffer.readShortString();
            const exchange = connector.rx_buffer.readShortString();
            const routing_key = connector.rx_buffer.readShortString();
            const arguments = connector.rx_buffer.readTable();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Queue@{any}.Unbind", .{connector.channel});
            return Unbind{
                .reserved_1 = reserved_1,
                .queue = queue,
                .exchange = exchange,
                .routing_key = routing_key,
                .arguments = arguments,
            };
        }
    };
    pub const UNBIND_METHOD = 50;
    pub fn unbindSync(
        connector: *Connector,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        arguments: ?*Table,
    ) !UnbindOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(QUEUE_CLASS, UNBIND_METHOD);
        const reserved_1 = 0;
        connector.tx_buffer.writeU16(reserved_1);
        connector.tx_buffer.writeShortString(queue);
        connector.tx_buffer.writeShortString(exchange);
        connector.tx_buffer.writeShortString(routing_key);
        connector.tx_buffer.writeTable(arguments);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Queue@{any}.Unbind ->", .{connector.channel});
        return awaitUnbindOk(connector);
    }

    // unbind
    pub fn awaitUnbind(connector: *Connector) !Unbind {
        return connector.awaitMethod(Unbind);
    }

    // unbind-ok

    pub const UnbindOk = struct {
        pub const CLASS = 50;
        pub const METHOD = 51;

        pub fn read(connector: *Connector) !UnbindOk {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Queue@{any}.Unbind_ok", .{connector.channel});
            return UnbindOk{};
        }
    };
    pub const UNBIND_OK_METHOD = 51;
    pub fn unbindOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.UNBIND_OK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Queue@{any}.Unbind_ok ->", .{connector.channel});
    }

    // unbind_ok
    pub fn awaitUnbindOk(connector: *Connector) !UnbindOk {
        return connector.awaitMethod(UnbindOk);
    }

    // purge

    pub const Purge = struct {
        pub const CLASS = 50;
        pub const METHOD = 30;

        reserved_1: u16,
        queue: []const u8,
        no_wait: bool,

        pub fn read(connector: *Connector) !Purge {
            const reserved_1 = connector.rx_buffer.readU16();
            const queue = connector.rx_buffer.readShortString();
            const bitset0 = connector.rx_buffer.readU8();
            const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Queue@{any}.Purge", .{connector.channel});
            return Purge{
                .reserved_1 = reserved_1,
                .queue = queue,
                .no_wait = no_wait,
            };
        }
    };
    pub const PURGE_METHOD = 30;
    pub fn purgeSync(
        connector: *Connector,
        queue: []const u8,
        no_wait: bool,
    ) !PurgeOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(QUEUE_CLASS, PURGE_METHOD);
        const reserved_1 = 0;
        connector.tx_buffer.writeU16(reserved_1);
        connector.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_wait) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Queue@{any}.Purge ->", .{connector.channel});
        return awaitPurgeOk(connector);
    }

    // purge
    pub fn awaitPurge(connector: *Connector) !Purge {
        return connector.awaitMethod(Purge);
    }

    // purge-ok

    pub const PurgeOk = struct {
        pub const CLASS = 50;
        pub const METHOD = 31;

        message_count: u32,

        pub fn read(connector: *Connector) !PurgeOk {
            const message_count = connector.rx_buffer.readU32();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Queue@{any}.Purge_ok", .{connector.channel});
            return PurgeOk{
                .message_count = message_count,
            };
        }
    };
    pub const PURGE_OK_METHOD = 31;
    pub fn purgeOkAsync(
        connector: *Connector,
        message_count: u32,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.PURGE_OK_METHOD);
        connector.tx_buffer.writeU32(message_count);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Queue@{any}.Purge_ok ->", .{connector.channel});
    }

    // purge_ok
    pub fn awaitPurgeOk(connector: *Connector) !PurgeOk {
        return connector.awaitMethod(PurgeOk);
    }

    // delete

    pub const Delete = struct {
        pub const CLASS = 50;
        pub const METHOD = 40;

        reserved_1: u16,
        queue: []const u8,
        if_unused: bool,
        if_empty: bool,
        no_wait: bool,

        pub fn read(connector: *Connector) !Delete {
            const reserved_1 = connector.rx_buffer.readU16();
            const queue = connector.rx_buffer.readShortString();
            const bitset0 = connector.rx_buffer.readU8();
            const if_unused = if (bitset0 & (1 << 0) == 0) true else false;
            const if_empty = if (bitset0 & (1 << 1) == 0) true else false;
            const no_wait = if (bitset0 & (1 << 2) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Queue@{any}.Delete", .{connector.channel});
            return Delete{
                .reserved_1 = reserved_1,
                .queue = queue,
                .if_unused = if_unused,
                .if_empty = if_empty,
                .no_wait = no_wait,
            };
        }
    };
    pub const DELETE_METHOD = 40;
    pub fn deleteSync(
        connector: *Connector,
        queue: []const u8,
        if_unused: bool,
        if_empty: bool,
        no_wait: bool,
    ) !DeleteOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(QUEUE_CLASS, DELETE_METHOD);
        const reserved_1 = 0;
        connector.tx_buffer.writeU16(reserved_1);
        connector.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (if_unused) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (if_empty) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        if (no_wait) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Queue@{any}.Delete ->", .{connector.channel});
        return awaitDeleteOk(connector);
    }

    // delete
    pub fn awaitDelete(connector: *Connector) !Delete {
        return connector.awaitMethod(Delete);
    }

    // delete-ok

    pub const DeleteOk = struct {
        pub const CLASS = 50;
        pub const METHOD = 41;

        message_count: u32,

        pub fn read(connector: *Connector) !DeleteOk {
            const message_count = connector.rx_buffer.readU32();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Queue@{any}.Delete_ok", .{connector.channel});
            return DeleteOk{
                .message_count = message_count,
            };
        }
    };
    pub const DELETE_OK_METHOD = 41;
    pub fn deleteOkAsync(
        connector: *Connector,
        message_count: u32,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.DELETE_OK_METHOD);
        connector.tx_buffer.writeU32(message_count);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Queue@{any}.Delete_ok ->", .{connector.channel});
    }

    // delete_ok
    pub fn awaitDeleteOk(connector: *Connector) !DeleteOk {
        return connector.awaitMethod(DeleteOk);
    }
};

// basic
pub const Basic = struct {
    pub const BASIC_CLASS = 60;

    // qos

    pub const Qos = struct {
        pub const CLASS = 60;
        pub const METHOD = 10;

        prefetch_size: u32,
        prefetch_count: u16,
        global: bool,

        pub fn read(connector: *Connector) !Qos {
            const prefetch_size = connector.rx_buffer.readU32();
            const prefetch_count = connector.rx_buffer.readU16();
            const bitset0 = connector.rx_buffer.readU8();
            const global = if (bitset0 & (1 << 0) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Qos", .{connector.channel});
            return Qos{
                .prefetch_size = prefetch_size,
                .prefetch_count = prefetch_count,
                .global = global,
            };
        }
    };
    pub const QOS_METHOD = 10;
    pub fn qosSync(
        connector: *Connector,
        prefetch_size: u32,
        prefetch_count: u16,
        global: bool,
    ) !QosOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, QOS_METHOD);
        connector.tx_buffer.writeU32(prefetch_size);
        connector.tx_buffer.writeU16(prefetch_count);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (global) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Qos ->", .{connector.channel});
        return awaitQosOk(connector);
    }

    // qos
    pub fn awaitQos(connector: *Connector) !Qos {
        return connector.awaitMethod(Qos);
    }

    // qos-ok

    pub const QosOk = struct {
        pub const CLASS = 60;
        pub const METHOD = 11;

        pub fn read(connector: *Connector) !QosOk {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Qos_ok", .{connector.channel});
            return QosOk{};
        }
    };
    pub const QOS_OK_METHOD = 11;
    pub fn qosOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.QOS_OK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Qos_ok ->", .{connector.channel});
    }

    // qos_ok
    pub fn awaitQosOk(connector: *Connector) !QosOk {
        return connector.awaitMethod(QosOk);
    }

    // consume

    pub const Consume = struct {
        pub const CLASS = 60;
        pub const METHOD = 20;

        reserved_1: u16,
        queue: []const u8,
        consumer_tag: []const u8,
        no_local: bool,
        no_ack: bool,
        exclusive: bool,
        no_wait: bool,
        arguments: Table,

        pub fn read(connector: *Connector) !Consume {
            const reserved_1 = connector.rx_buffer.readU16();
            const queue = connector.rx_buffer.readShortString();
            const consumer_tag = connector.rx_buffer.readShortString();
            const bitset0 = connector.rx_buffer.readU8();
            const no_local = if (bitset0 & (1 << 0) == 0) true else false;
            const no_ack = if (bitset0 & (1 << 1) == 0) true else false;
            const exclusive = if (bitset0 & (1 << 2) == 0) true else false;
            const no_wait = if (bitset0 & (1 << 3) == 0) true else false;
            const arguments = connector.rx_buffer.readTable();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Consume", .{connector.channel});
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
        }
    };
    pub const CONSUME_METHOD = 20;
    pub fn consumeSync(
        connector: *Connector,
        queue: []const u8,
        consumer_tag: []const u8,
        no_local: bool,
        no_ack: bool,
        exclusive: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) !ConsumeOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, CONSUME_METHOD);
        const reserved_1 = 0;
        connector.tx_buffer.writeU16(reserved_1);
        connector.tx_buffer.writeShortString(queue);
        connector.tx_buffer.writeShortString(consumer_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_local) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (no_ack) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        if (exclusive) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        if (no_wait) bitset0 |= (_bit << 3) else bitset0 &= ~(_bit << 3);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.writeTable(arguments);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Consume ->", .{connector.channel});
        return awaitConsumeOk(connector);
    }

    // consume
    pub fn awaitConsume(connector: *Connector) !Consume {
        return connector.awaitMethod(Consume);
    }

    // consume-ok

    pub const ConsumeOk = struct {
        pub const CLASS = 60;
        pub const METHOD = 21;

        consumer_tag: []const u8,

        pub fn read(connector: *Connector) !ConsumeOk {
            const consumer_tag = connector.rx_buffer.readShortString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Consume_ok", .{connector.channel});
            return ConsumeOk{
                .consumer_tag = consumer_tag,
            };
        }
    };
    pub const CONSUME_OK_METHOD = 21;
    pub fn consumeOkAsync(
        connector: *Connector,
        consumer_tag: []const u8,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.CONSUME_OK_METHOD);
        connector.tx_buffer.writeShortString(consumer_tag);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Consume_ok ->", .{connector.channel});
    }

    // consume_ok
    pub fn awaitConsumeOk(connector: *Connector) !ConsumeOk {
        return connector.awaitMethod(ConsumeOk);
    }

    // cancel

    pub const Cancel = struct {
        pub const CLASS = 60;
        pub const METHOD = 30;

        consumer_tag: []const u8,
        no_wait: bool,

        pub fn read(connector: *Connector) !Cancel {
            const consumer_tag = connector.rx_buffer.readShortString();
            const bitset0 = connector.rx_buffer.readU8();
            const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Cancel", .{connector.channel});
            return Cancel{
                .consumer_tag = consumer_tag,
                .no_wait = no_wait,
            };
        }
    };
    pub const CANCEL_METHOD = 30;
    pub fn cancelSync(
        connector: *Connector,
        consumer_tag: []const u8,
        no_wait: bool,
    ) !CancelOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, CANCEL_METHOD);
        connector.tx_buffer.writeShortString(consumer_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_wait) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Cancel ->", .{connector.channel});
        return awaitCancelOk(connector);
    }

    // cancel
    pub fn awaitCancel(connector: *Connector) !Cancel {
        return connector.awaitMethod(Cancel);
    }

    // cancel-ok

    pub const CancelOk = struct {
        pub const CLASS = 60;
        pub const METHOD = 31;

        consumer_tag: []const u8,

        pub fn read(connector: *Connector) !CancelOk {
            const consumer_tag = connector.rx_buffer.readShortString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Cancel_ok", .{connector.channel});
            return CancelOk{
                .consumer_tag = consumer_tag,
            };
        }
    };
    pub const CANCEL_OK_METHOD = 31;
    pub fn cancelOkAsync(
        connector: *Connector,
        consumer_tag: []const u8,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.CANCEL_OK_METHOD);
        connector.tx_buffer.writeShortString(consumer_tag);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Cancel_ok ->", .{connector.channel});
    }

    // cancel_ok
    pub fn awaitCancelOk(connector: *Connector) !CancelOk {
        return connector.awaitMethod(CancelOk);
    }

    // publish

    pub const Publish = struct {
        pub const CLASS = 60;
        pub const METHOD = 40;

        reserved_1: u16,
        exchange: []const u8,
        routing_key: []const u8,
        mandatory: bool,
        immediate: bool,

        pub fn read(connector: *Connector) !Publish {
            const reserved_1 = connector.rx_buffer.readU16();
            const exchange = connector.rx_buffer.readShortString();
            const routing_key = connector.rx_buffer.readShortString();
            const bitset0 = connector.rx_buffer.readU8();
            const mandatory = if (bitset0 & (1 << 0) == 0) true else false;
            const immediate = if (bitset0 & (1 << 1) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Publish", .{connector.channel});
            return Publish{
                .reserved_1 = reserved_1,
                .exchange = exchange,
                .routing_key = routing_key,
                .mandatory = mandatory,
                .immediate = immediate,
            };
        }
    };
    pub const PUBLISH_METHOD = 40;
    pub fn publishAsync(
        connector: *Connector,
        exchange: []const u8,
        routing_key: []const u8,
        mandatory: bool,
        immediate: bool,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.PUBLISH_METHOD);
        const reserved_1 = 0;
        connector.tx_buffer.writeU16(reserved_1);
        connector.tx_buffer.writeShortString(exchange);
        connector.tx_buffer.writeShortString(routing_key);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (mandatory) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (immediate) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Publish ->", .{connector.channel});
    }

    // publish
    pub fn awaitPublish(connector: *Connector) !Publish {
        return connector.awaitMethod(Publish);
    }

    // return

    pub const Return = struct {
        pub const CLASS = 60;
        pub const METHOD = 50;

        reply_code: u16,
        reply_text: []const u8,
        exchange: []const u8,
        routing_key: []const u8,

        pub fn read(connector: *Connector) !Return {
            const reply_code = connector.rx_buffer.readU16();
            const reply_text = connector.rx_buffer.readShortString();
            const exchange = connector.rx_buffer.readShortString();
            const routing_key = connector.rx_buffer.readShortString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Return", .{connector.channel});
            return Return{
                .reply_code = reply_code,
                .reply_text = reply_text,
                .exchange = exchange,
                .routing_key = routing_key,
            };
        }
    };
    pub const RETURN_METHOD = 50;
    pub fn returnAsync(
        connector: *Connector,
        reply_code: u16,
        reply_text: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.RETURN_METHOD);
        connector.tx_buffer.writeU16(reply_code);
        connector.tx_buffer.writeShortString(reply_text);
        connector.tx_buffer.writeShortString(exchange);
        connector.tx_buffer.writeShortString(routing_key);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Return ->", .{connector.channel});
    }

    // @"return"
    pub fn awaitReturn(connector: *Connector) !Return {
        return connector.awaitMethod(Return);
    }

    // deliver

    pub const Deliver = struct {
        pub const CLASS = 60;
        pub const METHOD = 60;

        consumer_tag: []const u8,
        delivery_tag: u64,
        redelivered: bool,
        exchange: []const u8,
        routing_key: []const u8,

        pub fn read(connector: *Connector) !Deliver {
            const consumer_tag = connector.rx_buffer.readShortString();
            const delivery_tag = connector.rx_buffer.readU64();
            const bitset0 = connector.rx_buffer.readU8();
            const redelivered = if (bitset0 & (1 << 0) == 0) true else false;
            const exchange = connector.rx_buffer.readShortString();
            const routing_key = connector.rx_buffer.readShortString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Deliver", .{connector.channel});
            return Deliver{
                .consumer_tag = consumer_tag,
                .delivery_tag = delivery_tag,
                .redelivered = redelivered,
                .exchange = exchange,
                .routing_key = routing_key,
            };
        }
    };
    pub const DELIVER_METHOD = 60;
    pub fn deliverAsync(
        connector: *Connector,
        consumer_tag: []const u8,
        delivery_tag: u64,
        redelivered: bool,
        exchange: []const u8,
        routing_key: []const u8,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.DELIVER_METHOD);
        connector.tx_buffer.writeShortString(consumer_tag);
        connector.tx_buffer.writeU64(delivery_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (redelivered) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.writeShortString(exchange);
        connector.tx_buffer.writeShortString(routing_key);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Deliver ->", .{connector.channel});
    }

    // deliver
    pub fn awaitDeliver(connector: *Connector) !Deliver {
        return connector.awaitMethod(Deliver);
    }

    // get

    pub const Get = struct {
        pub const CLASS = 60;
        pub const METHOD = 70;

        reserved_1: u16,
        queue: []const u8,
        no_ack: bool,

        pub fn read(connector: *Connector) !Get {
            const reserved_1 = connector.rx_buffer.readU16();
            const queue = connector.rx_buffer.readShortString();
            const bitset0 = connector.rx_buffer.readU8();
            const no_ack = if (bitset0 & (1 << 0) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Get", .{connector.channel});
            return Get{
                .reserved_1 = reserved_1,
                .queue = queue,
                .no_ack = no_ack,
            };
        }
    };
    pub const GET_METHOD = 70;
    pub fn getSync(
        connector: *Connector,
        queue: []const u8,
        no_ack: bool,
    ) !GetEmpty {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, GET_METHOD);
        const reserved_1 = 0;
        connector.tx_buffer.writeU16(reserved_1);
        connector.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_ack) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Get ->", .{connector.channel});
        return awaitGetEmpty(connector);
    }

    // get
    pub fn awaitGet(connector: *Connector) !Get {
        return connector.awaitMethod(Get);
    }

    // get-ok

    pub const GetOk = struct {
        pub const CLASS = 60;
        pub const METHOD = 71;

        delivery_tag: u64,
        redelivered: bool,
        exchange: []const u8,
        routing_key: []const u8,
        message_count: u32,

        pub fn read(connector: *Connector) !GetOk {
            const delivery_tag = connector.rx_buffer.readU64();
            const bitset0 = connector.rx_buffer.readU8();
            const redelivered = if (bitset0 & (1 << 0) == 0) true else false;
            const exchange = connector.rx_buffer.readShortString();
            const routing_key = connector.rx_buffer.readShortString();
            const message_count = connector.rx_buffer.readU32();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Get_ok", .{connector.channel});
            return GetOk{
                .delivery_tag = delivery_tag,
                .redelivered = redelivered,
                .exchange = exchange,
                .routing_key = routing_key,
                .message_count = message_count,
            };
        }
    };
    pub const GET_OK_METHOD = 71;
    pub fn getOkAsync(
        connector: *Connector,
        delivery_tag: u64,
        redelivered: bool,
        exchange: []const u8,
        routing_key: []const u8,
        message_count: u32,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.GET_OK_METHOD);
        connector.tx_buffer.writeU64(delivery_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (redelivered) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.writeShortString(exchange);
        connector.tx_buffer.writeShortString(routing_key);
        connector.tx_buffer.writeU32(message_count);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Get_ok ->", .{connector.channel});
    }

    // get_ok
    pub fn awaitGetOk(connector: *Connector) !GetOk {
        return connector.awaitMethod(GetOk);
    }

    // get-empty

    pub const GetEmpty = struct {
        pub const CLASS = 60;
        pub const METHOD = 72;

        reserved_1: []const u8,

        pub fn read(connector: *Connector) !GetEmpty {
            const reserved_1 = connector.rx_buffer.readShortString();
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Get_empty", .{connector.channel});
            return GetEmpty{
                .reserved_1 = reserved_1,
            };
        }
    };
    pub const GET_EMPTY_METHOD = 72;
    pub fn getEmptyAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.GET_EMPTY_METHOD);
        const reserved_1 = "";
        connector.tx_buffer.writeShortString(reserved_1);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Get_empty ->", .{connector.channel});
    }

    // get_empty
    pub fn awaitGetEmpty(connector: *Connector) !GetEmpty {
        return connector.awaitMethod(GetEmpty);
    }

    // ack

    pub const Ack = struct {
        pub const CLASS = 60;
        pub const METHOD = 80;

        delivery_tag: u64,
        multiple: bool,

        pub fn read(connector: *Connector) !Ack {
            const delivery_tag = connector.rx_buffer.readU64();
            const bitset0 = connector.rx_buffer.readU8();
            const multiple = if (bitset0 & (1 << 0) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Ack", .{connector.channel});
            return Ack{
                .delivery_tag = delivery_tag,
                .multiple = multiple,
            };
        }
    };
    pub const ACK_METHOD = 80;
    pub fn ackAsync(
        connector: *Connector,
        delivery_tag: u64,
        multiple: bool,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.ACK_METHOD);
        connector.tx_buffer.writeU64(delivery_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (multiple) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Ack ->", .{connector.channel});
    }

    // ack
    pub fn awaitAck(connector: *Connector) !Ack {
        return connector.awaitMethod(Ack);
    }

    // reject

    pub const Reject = struct {
        pub const CLASS = 60;
        pub const METHOD = 90;

        delivery_tag: u64,
        requeue: bool,

        pub fn read(connector: *Connector) !Reject {
            const delivery_tag = connector.rx_buffer.readU64();
            const bitset0 = connector.rx_buffer.readU8();
            const requeue = if (bitset0 & (1 << 0) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Reject", .{connector.channel});
            return Reject{
                .delivery_tag = delivery_tag,
                .requeue = requeue,
            };
        }
    };
    pub const REJECT_METHOD = 90;
    pub fn rejectAsync(
        connector: *Connector,
        delivery_tag: u64,
        requeue: bool,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.REJECT_METHOD);
        connector.tx_buffer.writeU64(delivery_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (requeue) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Reject ->", .{connector.channel});
    }

    // reject
    pub fn awaitReject(connector: *Connector) !Reject {
        return connector.awaitMethod(Reject);
    }

    // recover-async

    pub const RecoverAsync = struct {
        pub const CLASS = 60;
        pub const METHOD = 100;

        requeue: bool,

        pub fn read(connector: *Connector) !RecoverAsync {
            const bitset0 = connector.rx_buffer.readU8();
            const requeue = if (bitset0 & (1 << 0) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Recover_async", .{connector.channel});
            return RecoverAsync{
                .requeue = requeue,
            };
        }
    };
    pub const RECOVER_ASYNC_METHOD = 100;
    pub fn recoverAsyncAsync(
        connector: *Connector,
        requeue: bool,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.RECOVER_ASYNC_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (requeue) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Recover_async ->", .{connector.channel});
    }

    // recover_async
    pub fn awaitRecoverAsync(connector: *Connector) !RecoverAsync {
        return connector.awaitMethod(RecoverAsync);
    }

    // recover

    pub const Recover = struct {
        pub const CLASS = 60;
        pub const METHOD = 110;

        requeue: bool,

        pub fn read(connector: *Connector) !Recover {
            const bitset0 = connector.rx_buffer.readU8();
            const requeue = if (bitset0 & (1 << 0) == 0) true else false;
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Recover", .{connector.channel});
            return Recover{
                .requeue = requeue,
            };
        }
    };
    pub const RECOVER_METHOD = 110;
    pub fn recoverAsync(
        connector: *Connector,
        requeue: bool,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.RECOVER_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (requeue) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        connector.tx_buffer.writeU8(bitset0);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Recover ->", .{connector.channel});
    }

    // recover
    pub fn awaitRecover(connector: *Connector) !Recover {
        return connector.awaitMethod(Recover);
    }

    // recover-ok

    pub const RecoverOk = struct {
        pub const CLASS = 60;
        pub const METHOD = 111;

        pub fn read(connector: *Connector) !RecoverOk {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Basic@{any}.Recover_ok", .{connector.channel});
            return RecoverOk{};
        }
    };
    pub const RECOVER_OK_METHOD = 111;
    pub fn recoverOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.RECOVER_OK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Basic@{any}.Recover_ok ->", .{connector.channel});
    }

    // recover_ok
    pub fn awaitRecoverOk(connector: *Connector) !RecoverOk {
        return connector.awaitMethod(RecoverOk);
    }
};

// tx
pub const Tx = struct {
    pub const TX_CLASS = 90;

    // select

    pub const Select = struct {
        pub const CLASS = 90;
        pub const METHOD = 10;

        pub fn read(connector: *Connector) !Select {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Tx@{any}.Select", .{connector.channel});
            return Select{};
        }
    };
    pub const SELECT_METHOD = 10;
    pub fn selectSync(
        connector: *Connector,
    ) !SelectOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(TX_CLASS, SELECT_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Tx@{any}.Select ->", .{connector.channel});
        return awaitSelectOk(connector);
    }

    // select
    pub fn awaitSelect(connector: *Connector) !Select {
        return connector.awaitMethod(Select);
    }

    // select-ok

    pub const SelectOk = struct {
        pub const CLASS = 90;
        pub const METHOD = 11;

        pub fn read(connector: *Connector) !SelectOk {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Tx@{any}.Select_ok", .{connector.channel});
            return SelectOk{};
        }
    };
    pub const SELECT_OK_METHOD = 11;
    pub fn selectOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(TX_CLASS, Tx.SELECT_OK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Tx@{any}.Select_ok ->", .{connector.channel});
    }

    // select_ok
    pub fn awaitSelectOk(connector: *Connector) !SelectOk {
        return connector.awaitMethod(SelectOk);
    }

    // commit

    pub const Commit = struct {
        pub const CLASS = 90;
        pub const METHOD = 20;

        pub fn read(connector: *Connector) !Commit {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Tx@{any}.Commit", .{connector.channel});
            return Commit{};
        }
    };
    pub const COMMIT_METHOD = 20;
    pub fn commitSync(
        connector: *Connector,
    ) !CommitOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(TX_CLASS, COMMIT_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Tx@{any}.Commit ->", .{connector.channel});
        return awaitCommitOk(connector);
    }

    // commit
    pub fn awaitCommit(connector: *Connector) !Commit {
        return connector.awaitMethod(Commit);
    }

    // commit-ok

    pub const CommitOk = struct {
        pub const CLASS = 90;
        pub const METHOD = 21;

        pub fn read(connector: *Connector) !CommitOk {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Tx@{any}.Commit_ok", .{connector.channel});
            return CommitOk{};
        }
    };
    pub const COMMIT_OK_METHOD = 21;
    pub fn commitOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(TX_CLASS, Tx.COMMIT_OK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Tx@{any}.Commit_ok ->", .{connector.channel});
    }

    // commit_ok
    pub fn awaitCommitOk(connector: *Connector) !CommitOk {
        return connector.awaitMethod(CommitOk);
    }

    // rollback

    pub const Rollback = struct {
        pub const CLASS = 90;
        pub const METHOD = 30;

        pub fn read(connector: *Connector) !Rollback {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Tx@{any}.Rollback", .{connector.channel});
            return Rollback{};
        }
    };
    pub const ROLLBACK_METHOD = 30;
    pub fn rollbackSync(
        connector: *Connector,
    ) !RollbackOk {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(TX_CLASS, ROLLBACK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Tx@{any}.Rollback ->", .{connector.channel});
        return awaitRollbackOk(connector);
    }

    // rollback
    pub fn awaitRollback(connector: *Connector) !Rollback {
        return connector.awaitMethod(Rollback);
    }

    // rollback-ok

    pub const RollbackOk = struct {
        pub const CLASS = 90;
        pub const METHOD = 31;

        pub fn read(connector: *Connector) !RollbackOk {
            try connector.rx_buffer.readEOF();
            std.log.debug("\t<- Tx@{any}.Rollback_ok", .{connector.channel});
            return RollbackOk{};
        }
    };
    pub const ROLLBACK_OK_METHOD = 31;
    pub fn rollbackOkAsync(
        connector: *Connector,
    ) !void {
        connector.tx_buffer.writeFrameHeader(.Method, connector.channel, 0);
        connector.tx_buffer.writeMethodHeader(TX_CLASS, Tx.ROLLBACK_OK_METHOD);
        connector.tx_buffer.updateFrameLength();
        // TODO: do we need to retry write (if n isn't as high as we expect)?
        _ = try std.posix.write(connector.file.handle, connector.tx_buffer.extent());
        connector.tx_buffer.reset();
        std.log.debug("Tx@{any}.Rollback_ok ->", .{connector.channel});
    }

    // rollback_ok
    pub fn awaitRollbackOk(connector: *Connector) !RollbackOk {
        return connector.awaitMethod(RollbackOk);
    }
};
