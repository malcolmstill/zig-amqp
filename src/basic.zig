const Message = @import("message.zig").Message;
const Connector = @import("connector.zig").Connector;
const proto = @import("protocol.zig");

pub const Basic = struct {
    pub const Consume = struct {
        pub const Options = struct {
            no_local: bool = false,
            no_ack: bool = false,
            exclusive: bool = false,
            no_wait: bool = false,
        };
        pub const Qos = struct {
            prefetch_size: u32 = 0,
            prefetch_count: u16 = 1,
            global: bool = false,
        };
    };

    pub const Consumer = struct {
        connector: Connector,
        delivery: proto.Basic.Deliver,

        pub fn next(consumer: *Consumer) !Message {
            consumer.delivery = try proto.Basic.awaitDeliver(&consumer.connector);
            const header = try consumer.connector.awaitHeader();
            const body = try consumer.connector.awaitBody();

            // TODO: a body may come in more than one part
            return Message{
                .header = header,
                .body = body,
            };
        }

        pub fn ack(consumer: *Consumer, multiple: bool) !void {
            _ = try proto.Basic.ackAsync(
                &consumer.connector,
                consumer.delivery.delivery_tag,
                multiple,
            );
        }
    };

    pub const Publish = struct {
        pub const Options = struct {
            mandatory: bool = false,
            immediate: bool = false,
        };
    };
};
