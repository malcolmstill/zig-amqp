const std = @import("std");
const os = std.os;
const amqp = @import("amqp");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = &gpa.allocator;

pub fn main() !void {
    defer _ = gpa.deinit();
    const stdout = &std.io.getStdOut().outStream();

    var rx_memory: [4096]u8 = undefined;
    var tx_memory: [4096]u8 = undefined;

    var conn = try amqp.connect(rx_memory[0..], tx_memory[0..], allocator, null, null);
    // std.debug.warn("ptr: {*}\n", .{&conn});
    // defer conn.deinit();
    std.debug.warn("Connected!\n", .{});

    // try conn.proto.blocked_resp("derp");
    var ch = try conn.channel();

    while(true) {
        // var arena = heap.ArenaAllocator.init(heap.page_allocator);
        // defer arena.deinit();
        // const allocator = &arena.allocator;

        const ret = conn.connector.dispatch(null) catch |err| {
            switch (err) {
                error.ConnectionResetByPeer => return err,
                else => {
                    return err;
                },
            }
        };
    }
}