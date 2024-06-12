const std = @import("std");
const amqp = @import("amqp");

var rx_memory: [4096]u8 = undefined;
var tx_memory: [4096]u8 = undefined;

pub fn main() !void {
    var conn = amqp.init(rx_memory[0..], tx_memory[0..]);
    const addr = try std.net.Address.parseIp4("127.0.0.1", 5672);
    try conn.connect(addr);

    var ch1 = try conn.channel();
    var ch2 = try conn.channel();

    var consumer1 = try ch1.basicConsume("simple_publish", .{ .no_ack = true }, null);
    var consumer2 = try ch2.basicConsume("simple_publish", .{ .no_ack = true }, null);
    var i: usize = 0;
    while (true) : (i += 1) {
        const message1 = try consumer1.next();
        _ = message1.header;
        const body1 = message1.body;
        std.debug.print("@1: {any}\n", .{body1});

        const message2 = try consumer2.next();
        _ = message2.header;
        const body2 = message2.body;
        std.debug.print("@2: {any}\n", .{body2});
    }
}
