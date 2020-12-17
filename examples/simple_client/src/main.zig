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
    std.debug.warn("Connected!\n", .{});

    var ch = try conn.channel();
    const q = try ch.queueDeclare("test", amqp.Queue.Options{}, null);

    while(true) {
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