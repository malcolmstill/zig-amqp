// A WireBuffer is an abstraction over a slice that knows how
// to read and write the AMQP messages
const std = @import("std");
const mem = std.mem;
const proto = @import("protocol.zig");
const Table = @import("table.zig").Table;

// TODO: Think about input sanitisation

pub const WireBuffer = struct {
    // the current position in the buffer
    mem: []u8 = undefined,
    head: usize = 0, // current reading position
    end: usize = 0,

    const Self = @This();

    pub fn init(slice: []u8) WireBuffer {
        return WireBuffer{
            .mem = slice,
            .head = 0,
            .end = 0,
        };
    }

    pub fn printSpan(self: *Self) void {
        for (self.mem[self.head..self.end], 0..) |byte, i| {
            std.debug.print("{x:0>2}", .{byte});
            if ((i + 1) % 8 == 0) std.debug.print("\n", .{}) else std.debug.print(" ", .{});
        }
        std.debug.print("\n", .{});
    }

    // move head back to beginning of buffer
    pub fn reset(self: *Self) void {
        self.head = 0;
    }

    pub fn isFull(self: *Self) bool {
        return self.end == self.mem.len; // Should this actually be self.mem.len
    }

    // shift moves data between head and end to the front of mem
    pub fn shift(self: *Self) void {
        const new_end = self.end - self.head;
        mem.copyForwards(u8, self.mem[0..new_end], self.mem[self.head..self.end]);
        self.head = 0;
        self.end = new_end;
    }

    // Returns a slice of everything between the start of mem and head
    pub fn extent(self: *Self) []u8 {
        return self.mem[0..self.head];
    }

    // This doesn't return an error because we should always use this after
    // reading into self.remaining() which already bounds amount.
    pub fn incrementEnd(self: *Self, amount: usize) void {
        self.end += amount;
    }

    // Returns a slice of everthing between end and the end of mem
    pub fn remaining(self: *Self) []u8 {
        return self.mem[self.end..];
    }

    pub fn isMoreData(self: *Self) bool {
        return self.head < self.mem.len;
    }

    pub fn readFrameHeader(self: *Self) !FrameHeader {
        if (self.end - self.head < @sizeOf(FrameHeader)) return error.FrameHeaderReadFailure;
        const frame_type = self.readU8();
        const channel = self.readU16();
        const size = self.readU32();
        // std.debug.print("frame_type: {any}, channel: {any}, size: {any}\n", .{frame_type, channel, size});

        return FrameHeader{
            .type = @enumFromInt(frame_type),
            .channel = channel,
            .size = size,
        };
    }

    // Returns true if there is enough data read for
    // a full frame
    pub fn frameReady(self: *Self) bool {
        const save_head = self.head;
        defer self.head = save_head;
        const frame_header = self.readFrameHeader() catch |err| {
            switch (err) {
                error.FrameHeaderReadFailure => return false,
            }
        };
        return (self.end - save_head) >= (8 + frame_header.size);
    }

    pub fn readEOF(self: *Self) !void {
        const byte = self.readU8();
        if (byte != 0xCE) return error.ExpectedEOF;
    }

    fn writeEOF(self: *Self) void {
        self.writeU8(0xCE);
    }

    pub fn writeFrameHeader(self: *Self, frame_type: FrameType, channel: u16, size: u32) void {
        self.writeU8(@intFromEnum(frame_type));
        self.writeU16(channel);
        self.writeU32(size); // This will be overwritten later
    }

    pub fn updateFrameLength(self: *Self) void {
        self.writeEOF();
        const head = self.head;
        self.head = 3;
        self.writeU32(@intCast(head - 8)); // size is head - header length (7 bytes) - frame end (1 bytes)
        self.head = head;
    }

    pub fn readMethodHeader(self: *Self) !MethodHeader {
        const class = self.readU16();
        const method = self.readU16();

        return MethodHeader{
            .class = class,
            .method = method,
        };
    }

    pub fn writeMethodHeader(self: *Self, class: u16, method: u16) void {
        self.writeU16(class);
        self.writeU16(method);
    }

    pub fn readHeader(self: *Self, frame_size: usize) !Header {
        const class = self.readU16();
        const weight = self.readU16();
        const body_size = self.readU64();
        const property_flags = self.readU16();
        const properties = self.mem[self.head .. self.head + (frame_size - 14)];
        self.head += (frame_size - 14);
        try self.readEOF();

        return Header{
            .class = class,
            .weight = weight,
            .body_size = body_size,
            .property_flags = property_flags,
            .properties = properties,
        };
    }

    pub fn writeHeader(self: *Self, channel: u16, size: u64, class: u16) void {
        self.writeFrameHeader(.Header, channel, 0);
        self.writeU16(class);
        self.writeU16(0);
        self.writeU64(size);
        self.writeU16(0);
        self.updateFrameLength();
    }

    pub fn readBody(self: *Self, frame_size: usize) ![]u8 {
        const body = self.mem[self.head .. self.head + frame_size];
        self.head += frame_size;
        try self.readEOF();

        return body;
    }

    pub fn writeBody(self: *Self, channel: u16, body: []const u8) void {
        self.writeFrameHeader(.Body, channel, 0);
        std.mem.copyForwards(u8, self.mem[self.head..], body);
        self.head += body.len;
        self.updateFrameLength();
    }

    pub fn writeHeartbeat(self: *Self) void {
        self.writeFrameHeader(.Heartbeat, 0, 0);
        self.updateFrameLength();
    }

    pub fn readU8(self: *Self) u8 {
        const r: u8 = self.mem[self.head];
        self.head += 1;
        return r;
    }

    pub fn writeU8(self: *Self, byte: u8) void {
        std.mem.writeInt(u8, &self.mem[self.head], byte, .big);
        self.head += 1;
    }

    pub fn readU16(self: *Self) u16 {
        const r = std.mem.readInt(u16, @ptrCast(&self.mem[self.head]), .big);
        self.head += @sizeOf(u16);
        return r;
    }

    pub fn writeU16(self: *Self, short: u16) void {
        std.mem.writeInt(u16, @ptrCast(&self.mem[self.head]), short, .big);
        self.head += 2;
    }

    pub fn readU32(self: *Self) u32 {
        const r = std.mem.readInt(u32, @ptrCast(&self.mem[self.head]), .big);
        self.head += @sizeOf(u32);
        return r;
    }

    pub fn writeU32(self: *Self, number: u32) void {
        std.mem.writeInt(u32, @ptrCast(&self.mem[self.head]), number, .big);
        self.head += @sizeOf(u32);
    }

    pub fn readU64(self: *Self) u64 {
        const r = std.mem.readInt(u64, @ptrCast(&self.mem[self.head]), .big);
        self.head += @sizeOf(u64);
        return r;
    }

    pub fn writeU64(self: *Self, number: u64) void {
        std.mem.writeInt(u64, @ptrCast(&self.mem[self.head]), number, .big);
        self.head += @sizeOf(u64);
    }

    pub fn readBool(self: *Self) bool {
        const r = self.readU8();
        if (r == 0) return false;
        return true;
    }

    pub fn writeBool(self: *Self, boolean: bool) void {
        self.writeU8(if (boolean) 1 else 0);
    }

    pub fn readShortString(self: *Self) []u8 {
        const length = self.readU8();
        const array = self.mem[self.head .. self.head + length];
        self.head += length;
        return array;
    }

    pub fn writeShortString(self: *Self, string: []const u8) void {
        self.writeU8(@intCast(string.len));
        std.mem.copyForwards(u8, self.mem[self.head..], string);
        self.head += string.len;
    }

    pub fn readLongString(self: *Self) []u8 {
        const length = self.readU32();
        const array = self.mem[self.head .. self.head + length];
        self.head += length;
        return array;
    }

    pub fn writeLongString(self: *Self, string: []const u8) void {
        self.writeU32(@intCast(string.len));
        std.mem.copyForwards(u8, self.mem[self.head..], string);
        self.head += string.len;
    }

    // 1. Save the current read head
    // 2. Read the length (u32) of the table (the length of data after the u32 length)
    // 3. Until we've reached the end of the table
    //      3a. Read a table key
    //      3b. Read the value type for the key
    //      3c. Read that type
    pub fn readTable(self: *Self) Table {
        const table_start = self.head;
        const length = self.readU32();

        while (self.head - table_start < (length + @sizeOf(u32))) {
            _ = self.readShortString();
            const t = self.readU8();

            switch (t) {
                'F' => {
                    _ = self.readTable();
                },
                't' => {
                    _ = self.readBool();
                },
                's' => {
                    _ = self.readShortString();
                },
                'S' => {
                    _ = self.readLongString();
                },
                else => continue,
            }
        }

        return Table{
            .buf = WireBuffer.init(self.mem[table_start..self.head]),
        };
    }

    // writeTable is making an assumption that we're using a separate
    // buffer to write all the fields / values separately, then all
    // we have to do is copy them
    // TODO: thought: we might have this take *Table instead
    //       if we did, we could maybe make use of the len field
    //       in table to avoid provide a backing store for an empty
    //       table. We would simply chekc that length first, and
    //       if it's zeroe, manually write the 0 length, otherwise
    //       do the mem.copy
    pub fn writeTable(self: *Self, table: ?*Table) void {
        if (table) |t| {
            const table_bytes = t.buf.extent();
            std.mem.copyForwards(u8, self.mem[self.head..], table_bytes);
            self.head += table_bytes.len;
        } else {
            self.writeU32(0);
        }
    }
};

pub const FrameHeader = struct {
    type: FrameType = .Method,
    channel: u16 = 0,
    size: u32 = 0,
};

const FrameType = enum(u8) {
    Method = proto.FRAME_METHOD,
    Header = proto.FRAME_HEADER,
    Body = proto.FRAME_BODY,
    Heartbeat = proto.FRAME_HEARTBEAT,
};

const MethodHeader = struct {
    class: u16 = 0,
    method: u16 = 0,
};

pub const Header = struct {
    class: u16 = 0,
    weight: u16 = 0,
    body_size: u64 = 0,
    property_flags: u16 = 0,
    // TODO: I don't understand the properties field
    properties: []u8 = undefined,
};

const testing = std.testing;

test "buffer is full" {
    var memory: [16]u8 = [_]u8{0} ** 16;
    var buf = WireBuffer.init(memory[0..]);

    try testing.expect(buf.isFull() == false);
    buf.incrementEnd(16); // simluate writing 16 bytes into buffer

    // The buffer should now be full
    try testing.expect(buf.isFull() == true);
    try testing.expect(buf.remaining().len == 0);
}

test "basic write / read" {
    var rx_memory: [1024]u8 = [_]u8{0} ** 1024;
    var tx_memory: [1024]u8 = [_]u8{0} ** 1024;
    var table_memory: [1024]u8 = [_]u8{0} ** 1024;

    var rx_buf = WireBuffer.init(rx_memory[0..]);
    var tx_buf = WireBuffer.init(tx_memory[0..]);

    // Write to tx_buf (imagine this is the server's buffer)
    tx_buf.writeU8(22);
    tx_buf.writeU16(23);
    tx_buf.writeU32(24);
    tx_buf.writeShortString("Hello");
    tx_buf.writeLongString("World");
    tx_buf.writeBool(true);
    var tx_table = Table.init(table_memory[0..]);
    tx_table.insertBool("flag1", true);
    tx_table.insertBool("flag2", false);
    tx_table.insertLongString("longstring", "zig is the best");
    tx_buf.writeTable(&tx_table);

    // Simulate transmission
    mem.copyForwards(u8, rx_buf.remaining(), tx_buf.extent());
    rx_buf.incrementEnd(tx_buf.extent().len);

    // Read from rx_buf (image this is the client's buffer)
    try testing.expect(rx_buf.readU8() == 22);
    try testing.expect(rx_buf.readU16() == 23);
    try testing.expect(rx_buf.readU32() == 24);
    try testing.expect(mem.eql(u8, rx_buf.readShortString(), "Hello"));
    try testing.expect(mem.eql(u8, rx_buf.readLongString(), "World"));
    try testing.expect(rx_buf.readBool() == true);
    var rx_table = rx_buf.readTable();
    try testing.expect(rx_table.lookup(bool, "flag1").? == true);
    try testing.expect(rx_table.lookup(bool, "flag2").? == false);
    try testing.expect(mem.eql(u8, rx_table.lookup([]u8, "longstring").?, "zig is the best"));
}
