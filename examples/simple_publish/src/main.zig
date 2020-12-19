const std = @import("std");
const amqp = @import("amqp");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = &gpa.allocator;

var rx_memory: [4096]u8 = undefined;
var tx_memory: [4096]u8 = undefined;

pub fn main() !void {
    defer _ = gpa.deinit();

    var conn = amqp.init(rx_memory[0..], tx_memory[0..]);
    const addr = try std.net.Address.parseIp4("127.0.0.1", 5672);
    try conn.connect(addr);

    var ch = try conn.channel();
    var q = try ch.queueDeclare("simple_publish", amqp.Queue.Options{}, null);

    try ch.basicPublish("", "simple_publish", "hello world", amqp.Basic.Publish.Options{});
}
