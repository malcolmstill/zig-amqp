const std = @import("std");
const os = std.os;
const heap = std.heap;
const Conn = @import("connection.zig").Conn;
const channel = @import("channel.zig");

pub fn main() !void {
    const stdout = &std.io.getStdOut().outStream();

    var conn = try Conn.open(heap.page_allocator, null, null);
    defer conn.deinit();
    std.debug.warn("Connected!\n", .{});

    var ch = try channel.open(conn);

    while(true) {
        var arena = heap.ArenaAllocator.init(heap.page_allocator);
        defer arena.deinit();
        const allocator = &arena.allocator;

        const ret = conn.dispatch(null) catch |err| {
            switch (err) {
                error.ConnectionResetByPeer => return err,
                else => {
                    return err;
                },
            }
        };
    }
}