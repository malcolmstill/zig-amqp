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

    var conn = amqp.init(rx_memory[0..], tx_memory[0..]);
    try conn.connect(allocator, null, null);

    var ch = try conn.channel();

    // If queue "test" is already declared and we give the wrong details we
    // might get a channel error. This shows we can recover:
    // _ = ch.queueDeclare("test", amqp.Queue.Options{}, null) catch |err| {
    //     std.debug.warn("{}\n", .{err});

    //     ch = try conn.channel();
    // };

    const q2 = ch.queueDeclare("test2", amqp.Queue.Options{}, null);

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