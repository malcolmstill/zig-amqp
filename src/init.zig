const std = @import("std");
const proto = @import("protocol.zig");

fn connection_start() !void {
    std.debug.warn("connection_start\n", .{});
}

pub fn init() void {
    proto.CONNECTION_IMPLEMENTATION.start = connection_start;
}