const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const builtin = std.builtin;
const proto = @import("protocol.zig");
const Connector = @import("connection.zig").Connector;
const Connection = @import("connection.zig").Connection;

pub const Channel = struct {
    connector: Connector,
    channel_id: u16,

    const Self = @This();

    pub fn init(id: u16, connection: *Connection) Channel {
        var ch = Channel {
            .connector = connection.connector,
            .channel_id = id,
        };

        ch.connector.channel = id;

        return ch;
    }
};