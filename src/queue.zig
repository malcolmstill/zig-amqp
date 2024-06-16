const std = @import("std");
const Connector = @import("connector.zig").Connector;
const Channel = @import("channel.zig").Channel;

pub const Queue = struct {
    connector: Connector,

    pub const Options = struct {
        passive: bool = false,
        durable: bool = false,
        exclusive: bool = false,
        auto_delete: bool = false,
        no_wait: bool = false,
    };

    pub fn init(channel: *Channel) Queue {
        return Queue{
            .connector = channel.connector,
        };
    }
};
