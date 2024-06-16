// The Table struct presents a "view" over our rx buffer that we
// can query without needing to allocate memory into, say, a hash
// map. For small tables (I assume we'll only see smallish tables)
// this should be fine performance-wise.
const std = @import("std");
const mem = std.mem;
const WireBuffer = @import("wire.zig").WireBuffer;

pub const Table = struct {
    // a slice of our rx_buffer (with its own head and end)
    buf: WireBuffer = undefined,
    len: usize = 0,

    pub fn init(buffer: []u8) Table {
        var t = Table{
            .buf = WireBuffer.init(buffer),
            .len = 0,
        };
        t.buf.writeU32(0);
        return t;
    }

    // Lookup a value in the table. Note we need to know the type
    // we expect at compile time. We might not know this at which
    // point I guess I need a union. By the time we call lookup we
    // should already have validated the frame, so I think we maybe
    // can't error here.
    pub fn lookup(table: *Table, comptime T: type, key: []const u8) ?T {
        defer table.buf.reset();
        _ = table.buf.readU32();

        while (table.buf.isMoreData()) {
            const current_key = table.buf.readShortString();
            const correct_key = std.mem.eql(u8, key, current_key);
            const t = table.buf.readU8();
            switch (t) {
                'F' => {
                    const tbl = table.buf.readTable();
                    if (@TypeOf(tbl) == T and correct_key) return tbl;
                },
                't' => {
                    const b = table.buf.readBool();
                    if (@TypeOf(b) == T and correct_key) return b;
                },
                's' => {
                    const s = table.buf.readShortString();
                    if (@TypeOf(s) == T and correct_key) return s;
                },
                'S' => {
                    const s = table.buf.readLongString();
                    if (@TypeOf(s) == T and correct_key) return s;
                },
                else => {
                    // TODO: support all types as continue will return garbage
                    continue;
                },
            }
        }

        return null;
    }

    pub fn insertTable(table: *Table, key: []const u8, other_table: *Table) void {
        table.buf.writeShortString(key);
        table.buf.writeU8('F');
        table.buf.writeTable(other_table);
        table.updateLength();
    }

    pub fn insertBool(table: *Table, key: []const u8, boolean: bool) void {
        table.buf.writeShortString(key);
        table.buf.writeU8('t');
        table.buf.writeBool(boolean);
        table.updateLength();
    }

    // Apparently actual implementations don't use 's' for short string
    // (and therefore) I assume they don't use short strings (in tables)
    // at all
    // pub fn insertShortString(table: *Table, key: []u8, string: []u8) void {
    //     table.buf.writeShortString(key);
    //     table.buf.writeU8('s');
    //     table.buf.writeShortString(string);
    //     table.updateLength();
    // }

    pub fn insertLongString(table: *Table, key: []const u8, string: []const u8) void {
        table.buf.writeShortString(key);
        table.buf.writeU8('S');
        table.buf.writeLongString(string);
        table.updateLength();
    }

    fn updateLength(table: *Table) void {
        mem.writeInt(u32, @ptrCast(&table.buf.mem[0]), @intCast(table.buf.head - @sizeOf(u32)), .big);
    }

    pub fn print(table: *Table) void {
        for (table.buf.mem[0..table.buf.head]) |x| {
            std.debug.print("0x{x:0>2} ", .{x});
        }
        std.debug.print("\n", .{});
    }
};
