const std = @import("std");
const proto = @import("protocol.zig");
const Table = @import("table.zig").Table;
const WireBuffer = @import("wire.zig").WireBuffer;
const Conn = @import("connection.zig").Conn;

fn connection_start (conn: *Conn, version_major: u8, version_minor: u8, server_properties: *Table, mechanisms: []const u8, locales: []const u8) !void {
    const host = server_properties.lookup([]u8, "cluster_name");
    std.debug.warn("Connected to {} AMQP server (version {}.{})\nmechanisms: {}\nlocale: {}\n", .{
        host,
        version_major,
        version_minor,
        mechanisms,
        locales
    });

    std.debug.warn("product: {}\n", .{ server_properties.lookup([]u8, "product") });

    // if (server_properties.lookup(Table, "capabilities")) |*caps| {
    //     std.debug.warn("\tconnection.blocked: {}\n", .{ caps.lookup(bool, "connection.blocked") });
    // }

    var props_buffer: [1024]u8 = undefined;
    var props_wb: WireBuffer = WireBuffer.init(props_buffer[0..]);
    var client_properties: Table = Table.init(props_wb);

    client_properties.insertLongString("product", "Zig AMQP Library");
    client_properties.insertLongString("platform", "Zig 0.7.0");

    var caps_buf: [1024]u8 = undefined;
    var caps_wb: WireBuffer = WireBuffer.init(caps_buf[0..]);
    var capabilities: Table = Table.init(caps_wb);

    capabilities.insertBool("authentication_failure_close", true);
    capabilities.insertBool("basic.nack", true);
    capabilities.insertBool("connection.blocked", true);
    capabilities.insertBool("consumer_cancel_notify", true);
    capabilities.insertBool("publisher_confirms", true);
    client_properties.insertTable("capabilities", &capabilities);

    client_properties.insertLongString("information", "See https://github.com/malcolmstill/zig-amqp");
    client_properties.insertLongString("version", "0.0.1");

    std.debug.warn("client_properties:\n", .{});
    client_properties.print();
    std.debug.warn("end client_properties:\n", .{});

    // TODO: We want to be able to call start_ok_resp as a function
    //       rather than having to deal with buffers
    var connection: proto.Connection = proto.Connection { .conn = conn };
    try connection.start_ok_resp(
        &client_properties,
        "PLAIN",
        "\x00guest\x00guest",
        "en_US",
    );
}

pub fn init() void {
    proto.CONNECTION_IMPL.start = connection_start;
}