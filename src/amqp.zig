pub const Connection = @import("connection.zig").Connection;
pub const Queue = @import("queue.zig").Queue;
pub const Basic = @import("basic.zig").Basic;
pub const Table = @import("table.zig").Table;
pub const init = @import("connection.zig").Connection.init;

const testing = @import("std").testing;

test {
    _ = @import("basic.zig");
    _ = @import("channel.zig");
    _ = @import("connection.zig");
    _ = @import("connector.zig");
    _ = @import("protocol.zig");
    _ = @import("queue.zig");
    _ = @import("table.zig");
    _ = @import("wire.zig");
}
