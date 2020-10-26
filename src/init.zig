const std = @import("std");
const proto = @import("protocol.zig");

fn connection_start (version_major: u8, version_minor: u8, server_properties: []u8, mechanisms: []u8, locales: []u8) !void {
    std.debug.warn("Connected to AMQP server (version {}.{})\nmechanisms: {}\nlocale: {}\n", .{
        version_major,
        version_minor,
        mechanisms,
        locales
    });
}

pub fn init() void {
    proto.CONNECTION_IMPL.start = connection_start;
}