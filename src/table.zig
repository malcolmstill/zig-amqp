// The Table struct presents a "view" over our rx buffer that we
// can query without needing to allocate memory into, say, a hash
// map. For small tables (I assume we'll only see smallish tables)
// this should be fine performance-wise.
const std = @import("std");
const mem = std.mem;
const WireBuffer = @import("wire.zig").WireBuffer;

pub const Table = struct {
    // a slice of our rx_buffer
    buf: WireBuffer = undefined,
    len: usize = 0,

    const Self = @This();

    pub fn init(wire_buffer: WireBuffer) Table {
        var t = Table {
            .buf = wire_buffer,
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

    pub fn insertTable(self: *Self, key: []u8, table: Table) void {
        self.buf.writeShortString(key);
        self.buf.writeU8('F');
        self.buf.writeTable(table);
        self.updateLength();
    }

    pub fn insertBool(self: *Self, key: []u8, boolean: bool) void {
        self.buf.writeShortString(key);
        self.buf.writeU8('t');
        self.buf.writeBool(boolean);
        self.updateLength();
    }

    pub fn insertShortString(self: *Self, key: []u8, string: []u8) void {
        self.buf.writeShortString(key);
        self.buf.writeU8('s');
        self.buf.writeShortString(string);
        self.updateLength();
    }

    pub fn insertLongString(self: *Self, key: []u8, string: []u8) void {
        self.buf.writeShortString(key);
        self.buf.writeU8('S');
        self.buf.writeLongString(string);
        self.updateLength();
    }

    fn updateLength(self: *Self) void {
        mem.writeInt(
            u32,
            @ptrCast(*[@sizeOf(u32)]u8,
            &self.buf.mem[0]),
            @intCast(u32, self.buf.head - @sizeOf(u32)),
            .Big
        );
    }

    pub fn print(self: *Self) void {
        for (self.buf.mem[0..self.buf.head]) |x| {
            std.debug.warn("0x{x:0>2} ", .{x});
        }
        std.debug.warn("\n", .{});
    }
};