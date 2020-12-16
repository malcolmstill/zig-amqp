const std = @import("std");
const proto = @import("protocol.zig");
const Table = @import("table.zig").Table;
const WireBuffer = @import("wire.zig").WireBuffer;
const Conn = @import("connection.zig").Conn;

fn connection_start (conn: *Conn, version_major: u8, version_minor: u8, server_properties: *Table, mechanisms: []u8, locales: []u8) !void {
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

    // conn.tx_buffer.reset();
    // conn.tx_buffer.writeU8(64);
    // conn.tx_buffer.writeU16(22);
    // conn.tx_buffer.writeU32(22);
    // conn.tx_buffer.writeU64(22);
    // conn.tx_buffer.writeBool(true);
    // conn.tx_buffer.writeBool(false);
    // var text = [_]u8{'h', 'e', 'l', 'l', 'o'};
    // conn.tx_buffer.writeShortString(text[0..]);

    var props_buffer: [1024]u8 = undefined;
    var props_wb: WireBuffer = WireBuffer.init(props_buffer[0..]);
    var client_properties: Table = Table.init(props_wb);

    var key = [_]u8{'p', 'r', 'o', 'd', 'u', 'c', 't'};
    var value = [_]u8{'z', 'i', 'g', '-', 'a', 'm', 'q', 'p'};
    client_properties.insertLongString(key[0..], value[0..]);
    std.debug.warn("client_properties:\n", .{});
    client_properties.print();
    std.debug.warn("end client_properties:\n", .{});

    var mechanism = [_]u8{'P', 'L', 'A', 'I', 'N'};
    var repsonse = [_]u8{};
    var locale = [_]u8{'e', 'n', '_', 'U', 'S'};

    // TODO: We want to be able to call start_ok_resp as a function
    //       rather than having to deal with buffers
    var connection: proto.Connection = proto.Connection { .conn = conn };
    try connection.start_ok_resp(
        &client_properties,
        mechanism[0..],
        repsonse[0..],
        locale[0..],
    );
}

pub fn init() void {
    proto.CONNECTION_IMPL.start = connection_start;
}