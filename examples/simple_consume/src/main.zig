const std = @import("std");
const amqp = @import("amqp");

var memory: [2][2][4096]u8 = undefined;

pub fn main() !void {
    var conn = amqp.init(memory[0][0][0..], memory[0][1][0..]);
    const addr = try std.net.Address.parseIp4("127.0.0.1", 5672);
    try conn.connect(addr);

    var ch = try conn.channel(memory[1][0][0..], memory[1][1][0..]);

    var consumer = try ch.basicConsume("simple_publish", .{ .no_ack = true }, null);
    var i: usize = 0;
    while (true) : (i += 1) {
        var message = try consumer.next();
        var header = message.header;
        var body = message.body;
        std.debug.warn("{}\n", .{body});
    }
}
