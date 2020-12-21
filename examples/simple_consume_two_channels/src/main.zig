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
        var message1 = try consumer1.next();
        var header1 = message1.header;
        var body1 = message1.body;
        std.debug.warn("@1: {}\n", .{body1});

        var message2 = try consumer2.next();
        var header2 = message2.header;
        var body2 = message2.body;
        std.debug.warn("@2: {}\n", .{body2});
    }
}
