// The Table struct presents a "view" over our rx buffer that we
// can query without needing to allocate memory into, say, a hash
// map. For small tables (I assume we'll only see smallish tables)
// this should be fine performance-wise.
const std = @import("std");
const WireBuffer = @import("wire.zig").WireBuffer;

pub const Table = struct {
    // a slice of our rx_buffer
    buf: WireBuffer = undefined,

    const Self = @This();

    pub fn init(wire_buffer: WireBuffer) Table {
        return Table {
            .buffer = wire_buffer,
        };
    }

    // Lookup a value in the table. Note we need to know the type
    // we expect at compile time. We might not know this at which
    // point I guess I need a union 
    pub fn lookup(self: *Self, comptime T: type, key: []const u8) ?T {
        defer self.buf.reset();
        const length = self.buf.readU32();

        while (self.buf.is_more_data()) {
            const current_key = self.buf.readShortString();
            const correct_key = std.mem.eql(u8, key, current_key);
            const t = self.buf.readU8();
            switch (t) {
                'F' => {
                    var table = self.buf.readTable();
                    if (@TypeOf(table) == T and correct_key) return table;
                },
                't' => {
                    const b = self.buf.readBool();
                    if (@TypeOf(b) == T and correct_key) return b;
                },
                's' => {
                    const s = self.buf.readShortString();
                    if (@TypeOf(s) == T and correct_key) return s;
                },
                'S' => {
                    const s = self.buf.readLongString();
                    if (@TypeOf(s) == T and correct_key) return s;
                },
                else => {
                    // TODO: support all types
                    continue;
                },
            }
        }

        return null;
    }
};