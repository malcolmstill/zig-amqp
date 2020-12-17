const std = @import("std");
const proto = @import("protocol.zig");
const Table = @import("table.zig").Table;
const WireBuffer = @import("wire.zig").WireBuffer;
const Connector = @import("connector.zig").Connector;
const Connection = @import("connection.zig").Connection;

fn connection_start (connector: *Connector, version_major: u8, version_minor: u8, server_properties: ?*Table, mechanisms: []const u8, locales: []const u8) !void {
    const host = server_properties.?.lookup([]u8, "cluster_name");
    std.debug.warn("Connected to {} AMQP server (version {}.{})\nmechanisms: {}\nlocale: {}\n", .{
        host,
        version_major,
        version_minor,
        mechanisms,
        locales
    });

    var props_buffer: [1024]u8 = undefined;
    var client_properties: Table = Table.init(props_buffer[0..]);

    client_properties.insertLongString("product", "Zig AMQP Library");
    client_properties.insertLongString("platform", "Zig 0.7.0");

    // TODO: it's annoying having 3 lines for a single initialisation
    // UPDATE: thoughts. We can at least get rid of the caps_wb if Table.init
    //         does its own WireBuffer init from the backing buffer.
    //         Also, perhaps we can offer a raw slice backed Table.init and,
    //         say, a Table.initAllocator() that takes an allocator instead.
    //         This gives users the freedom to decide how they want to deal
    //         with memory.
    var caps_buf: [1024]u8 = undefined;
    var capabilities: Table = Table.init(caps_buf[0..]);

    capabilities.insertBool("authentication_failure_close", true);
    capabilities.insertBool("basic.nack", true);
    capabilities.insertBool("connection.blocked", true);
    capabilities.insertBool("consumer_cancel_notify", true);
    capabilities.insertBool("publisher_confirms", true);
    client_properties.insertTable("capabilities", &capabilities);

    client_properties.insertLongString("information", "See https://github.com/malcolmstill/zig-amqp");
    client_properties.insertLongString("version", "0.0.1");

    // TODO: We want to be able to call start_ok_resp as a function
    //       rather than having to deal with buffers.
    // UPDATE: the above TODO is what we now have, but we require extra
    //         buffers, and how do we size them. It would be nice to
    //         avoid allocations.
    try proto.Connection.start_ok_resp(connector, &client_properties, "PLAIN", "\x00guest\x00guest", "en_US");
}

fn tune(connector: *Connector, channel_max: u16, frame_max: u32, heartbeat: u16) !void {
    // TODO: we have to be careful here, how do we know this connector's parent
    //       is inside a Connection. It almost certainly will be, but if we
    //       received a spurious tune whilst some other type was expecting a message
    //       the connector used to dispatch the call will not be in Connection
    const connection = @fieldParentPtr(Connection, "connector", connector);
    connection.max_channels = channel_max;

    std.debug.warn("{}\n", .{connection});

    try proto.Connection.tune_ok_resp(connector, channel_max, frame_max, heartbeat);
}

fn open_ok(connector: *Connector) anyerror!void {
    return;
}

pub fn init() void {
    proto.CONNECTION_IMPL.start = connection_start;
    proto.CONNECTION_IMPL.tune = tune;
    proto.CONNECTION_IMPL.open_ok = open_ok;
    proto.CHANNEL_IMPL.open_ok = open_ok;
}