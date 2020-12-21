const std = @import("std");
const proto = @import("protocol.zig");
const Connector = @import("connector.zig").Connector;
const Connection = @import("connection.zig").Connection;
const Queue = @import("queue.zig").Queue;
const Basic = @import("basic.zig").Basic;
const Table = @import("table.zig").Table;
const WireBuffer = @import("wire.zig").WireBuffer;

pub const Channel = struct {
    connector: Connector,
    channel_id: u16,

    const Self = @This();

    pub fn init(id: u16, connection: *Connection, rx_memory: []u8, tx_memory: []u8) Channel {
        var ch = Channel{
            .connector = Connector{
                .file = connection.connector.file,
                .rx_buffer = WireBuffer.init(rx_memory),
                .tx_buffer = WireBuffer.init(tx_memory),
                .channel = id,
                .connection = connection,
            },
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

    pub fn basicConsume(self: *Self, name: []const u8, options: Basic.Consume.Options, args: ?*Table) !Basic.Consumer {
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

        return Basic.Consumer{
            .connector = self.connector,
        };
    }
};

pub fn atest(ch: *Channel, x: usize) void {
    std.debug.warn("{}\n", .{ch.file});
}
