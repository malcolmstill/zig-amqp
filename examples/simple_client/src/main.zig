const std = @import("std");
const os = std.os;
const amqp = @import("amqp");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = &gpa.allocator;

pub fn main() !void {
    defer _ = gpa.deinit();
    const stdout = &std.io.getStdOut().outStream();

    var conn = try amqp.connect(allocator, null, null);
    std.debug.warn("ptr: {*}\n", .{&conn});
    // defer conn.deinit();
    std.debug.warn("Connected!\n", .{});

    try conn.connection.blocked_resp("derp");
    // var ch = try channel.open(conn);

    while(true) {
        // var arena = heap.ArenaAllocator.init(heap.page_allocator);
        // defer arena.deinit();
        // const allocator = &arena.allocator;

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