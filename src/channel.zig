const std = @import("std");
const proto = @import("protocol.zig");
const Connector = @import("connector.zig").Connector;
const ClassMethod = @import("connector.zig").ClassMethod;
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
        var consume_ok = try proto.Basic.consumeSync(
            &self.connector,
            name,
            "",
            options.no_local,
            options.no_ack,
            options.exclusive,
            options.no_wait,
            args,
        );

        std.debug.warn("consume_sync returned\n", .{});

        // TODO: this should be const deliver: Deliver = proto.await_deliver();
        var deliver_ok = proto.Basic.awaitDeliver(&self.connector);
        // var received_response = false;
        // while (!received_response) {
        //     const expecting: ClassMethod = .{ .class = proto.BASIC_CLASS, .method = proto.Basic.DELIVER_METHOD };
        //     received_response = try self.connector.dispatch(expecting);
        // }

        // _ = try self.connector.dispatch(null);
        // _ = try self.connector.dispatch(null);
    }
};