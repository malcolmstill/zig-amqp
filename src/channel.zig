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
        var ch = Channel{
            .connector = connection.connector,
            .channel_id = id,
        };

        ch.connector.channel = id;

        return ch;
    }

    pub fn queueDeclare(self: *Self, name: []const u8, options: Queue.Options, args: ?*Table) !Queue {
        var declare = try proto.Queue.declareSync(
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

    pub fn basicPublish(self: *Self, exchange_name: []const u8, routing_key: []const u8, body: []const u8, options: Basic.Publish.Options) !void {
        try proto.Basic.publishAsync(
            &self.connector,
            exchange_name,
            routing_key,
            options.mandatory,
            options.immediate,
        );

        try self.connector.sendHeader(body.len, proto.Basic.BASIC_CLASS);
        try self.connector.sendBody(body);
    }

    pub fn basicConsume(self: *Self, name: []const u8, options: Basic.Consume.Options, args: ?*Table) !void {
        var consume = try proto.Basic.consumeSync(
            &self.connector,
            name,
            "",
            options.no_local,
            options.no_ack,
            options.exclusive,
            options.no_wait,
            args,
        );
        std.log.debug("consume: {}\n", .{consume});

        var deliver = proto.Basic.awaitDeliver(&self.connector);
        std.log.debug("deliver: {}\n", .{deliver});

        // _ = try self.connector.dispatch(null);
        // _ = try self.connector.dispatch(null);
    }
};
