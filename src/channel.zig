const std = @import("std");
const proto = @import("protocol.zig");
const Connector = @import("connector.zig").Connector;
const Connection = @import("connection.zig").Connection;
const Queue = @import("queue.zig").Queue;
const Basic = @import("basic.zig").Basic;
const Table = @import("table.zig").Table;

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

    pub fn queueDeclare(self: *Self, name: []const u8, options: Queue.Options, args: ?*Table) !Queue {
        try proto.Queue.declare_sync(
            &self.connector,
            name,
            options.passive,
            options.durable,
            options.exclusive,
            options.auto_delete,
            options.no_wait,
            args,
        );

        return Queue.init(self);
    }

    pub fn basicConsume(self: *Self, name: []const u8, options: Basic.Options, args: ?*Table) !void {
        var ctag: [32]u8 = undefined;
        try std.os.getrandom(ctag[0..]);

        for (ctag) |r, i| {
            ctag[i] = std.math.max(48, std.math.min(122, r));
        }

        try proto.Basic.consume_sync(
            &self.connector,
            name,
            ctag[0..],
            options.no_local,
            options.no_ack,
            options.exclusive,
            options.no_wait,
            args,
        );
    }
};