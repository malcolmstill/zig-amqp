const std = @import("std");
const Connector = @import("connector.zig").Connector;
const Channel = @import("channel.zig").Channel;

pub const Queue = struct {
    connector: Connector,

    const Self = @This();

    pub const Options = struct {
        passive: bool = false,
        durable: bool = false,
        exclusive: bool = false,
        auto_delete: bool = false,
        no_wait: bool = false,
    };

    pub fn init(channel: *Channel) Queue {
        var q = Queue {
            .connector = channel.connector,
        };

        return q;
    }
};