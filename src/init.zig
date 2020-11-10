const std = @import("std");
const proto = @import("protocol.zig");
const Table = @import("table.zig").Table;

fn connection_start (version_major: u8, version_minor: u8, server_properties: *Table, mechanisms: []u8, locales: []u8) !void {
    const host = server_properties.lookup([]u8, "cluster_name");
    std.debug.warn("Connected to {} AMQP server (version {}.{})\nmechanisms: {}\nlocale: {}\n", .{
        host,
        version_major,
        version_minor,
        mechanisms,
        locales
    });

    // std.debug.warn("product: {}\n", .{ server_properties.lookup([]u8, "product") });
    // std.debug.warn("platform: {}\n", .{ sp.lookup([]u8, "platform") });
    // if (sp.lookup(Table, "capabilities")) |*caps| {
        // std.debug.warn("\tconnection.blocked: {}\n", .{ caps.lookup(bool, "connection.blocked") });
    // }
    // try proto.start_ok_resp();
}

pub fn init() void {
    proto.CONNECTION_IMPL.start = connection_start;
}