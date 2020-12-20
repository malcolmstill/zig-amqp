const std = @import("std");
const amqp = @import("amqp");

var rx_memory: [4096]u8 = undefined;
var tx_memory: [4096]u8 = undefined;

pub fn main() !void {
    var conn = amqp.init(rx_memory[0..], tx_memory[0..]);
    const addr = try std.net.Address.parseIp4("127.0.0.1", 5672);
    try conn.connect(addr);

    var ch = try conn.channel();

    var consumer = try ch.basicConsume("simple_publish", .{ .no_ack = true }, null);
    var i: usize = 0;
    while (true) : (i += 1) {
        var message = try consumer.next();
        var header = message.header;
        var body = message.body;
        if (i % 10_000 == 0) {
            std.debug.warn("count: {}, last body: {}\n", .{ i, body });
        }
    }
}
