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
    };

    pub const Consumer = struct {
        connector: Connector,

        pub fn next(consumer: *Consumer) !Message {
            _ = try proto.Basic.awaitDeliver(&consumer.connector);
            const header = try consumer.connector.awaitHeader();
            const body = try consumer.connector.awaitBody();

            // TODO: a body may come in more than one part
            return Message{
                .header = header,
                .body = body,
            };
        }
    };

    pub const Publish = struct {
        pub const Options = struct {
            mandatory: bool = false,
            immediate: bool = false,
        };
    };
};
