const std = @import("std");
const amqp = @import("amqp");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = &gpa.allocator;

pub fn main() !void {
    defer _ = gpa.deinit();

    var rx_memory: [4096]u8 = undefined;
    var tx_memory: [4096]u8 = undefined;

    var conn = amqp.init(rx_memory[0..], tx_memory[0..]);
    const addr = try std.net.Address.parseIp4("127.0.0.1", 5672);
    try conn.connect(addr);

    var ch = try conn.channel();

    // If queue "test" is already declared and we give the wrong details we
    // might get a channel error. This shows we can recover:
    // _ = ch.queueDeclare("test", amqp.Queue.Options{}, null) catch |err| {
    //     std.debug.warn("{}\n", .{err});

    //     ch = try conn.channel();
    // };

    // const q2 = ch.queueDeclare("test2", amqp.Queue.Options{}, null);

    while (true) {
        try ch.basicConsume("test", amqp.Basic.Options{ .no_ack = false }, null);
    }
}
