const std = @import("std");
const os = std.os;
const fs = std.fs;
const proto = @import("protocol.zig");
const wire = @import("wire.zig");
const WireBuffer = @import("wire.zig").WireBuffer;
const Connection = @import("connection.zig").Connection;

// TODO: think up a better name for this
pub const Connector = struct {
    file: fs.File = undefined,
    // TODO: we're going to run into trouble real fast if we reallocate the buffers
    //       and we have a bunch of copies of Connector everywhere. I think we just
    //       need to store a pointer to the Connection
    rx_buffer: WireBuffer = undefined,
    tx_buffer: WireBuffer = undefined,
    connection: *Connection = undefined,
    channel: u16,

    const Self = @This();

    pub fn sendHeader(self: *Self, size: u64, class: u16) !void {
        self.tx_buffer.writeHeader(self.channel, size, class);
        const n = try std.os.write(self.file.handle, self.tx_buffer.extent());
        self.tx_buffer.reset();
    }

    pub fn sendBody(self: *Self, body: []const u8) !void {
        self.tx_buffer.writeBody(self.channel, body);
        const n = try std.os.write(self.file.handle, self.tx_buffer.extent());
        self.tx_buffer.reset();
    }
};
