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

    pub fn init(slice: []u8) WireBuffer {
        return WireBuffer{
            .mem = slice,
            .head = 0,
            .end = 0,
        };
    }

    pub fn printSpan(wire_buffer: *WireBuffer) void {
        for (wire_buffer.mem[wire_buffer.head..wire_buffer.end], 0..) |byte, i| {
            std.debug.print("{x:0>2}", .{byte});
            if ((i + 1) % 8 == 0) std.debug.print("\n", .{}) else std.debug.print(" ", .{});
        }
        std.debug.print("\n", .{});
    }

    // move head back to beginning of buffer
    pub fn reset(wire_buffer: *WireBuffer) void {
        wire_buffer.head = 0;
    }

    pub fn isFull(wire_buffer: *WireBuffer) bool {
        return wire_buffer.end == wire_buffer.mem.len; // Should this actually be wire_buffer.mem.len
    }

    // shift moves data between head and end to the front of mem
    pub fn shift(wire_buffer: *WireBuffer) void {
        const new_end = wire_buffer.end - wire_buffer.head;
        mem.copyForwards(u8, wire_buffer.mem[0..new_end], wire_buffer.mem[wire_buffer.head..wire_buffer.end]);
        wire_buffer.head = 0;
        wire_buffer.end = new_end;
    }

    // Returns a slice of everything between the start of mem and head
    pub fn extent(wire_buffer: *WireBuffer) []u8 {
        return wire_buffer.mem[0..wire_buffer.head];
    }

    // This doesn't return an error because we should always use this after
    // reading into wire_buffer.remaining() which already bounds amount.
    pub fn incrementEnd(wire_buffer: *WireBuffer, amount: usize) void {
        wire_buffer.end += amount;
    }

    // Returns a slice of everthing between end and the end of mem
    pub fn remaining(wire_buffer: *WireBuffer) []u8 {
        return wire_buffer.mem[wire_buffer.end..];
    }

    pub fn isMoreData(wire_buffer: *WireBuffer) bool {
        return wire_buffer.head < wire_buffer.mem.len;
    }

    pub fn readFrameHeader(wire_buffer: *WireBuffer) !FrameHeader {
        if (wire_buffer.end - wire_buffer.head < @sizeOf(FrameHeader)) return error.FrameHeaderReadFailure;
        const frame_type = wire_buffer.readU8();
        const channel = wire_buffer.readU16();
        const size = wire_buffer.readU32();
        // std.debug.print("frame_type: {any}, channel: {any}, size: {any}\n", .{frame_type, channel, size});

        return FrameHeader{
            .type = @enumFromInt(frame_type),
            .channel = channel,
            .size = size,
        };
    }

    // Returns true if there is enough data read for
    // a full frame
    pub fn frameReady(wire_buffer: *WireBuffer) bool {
        const save_head = wire_buffer.head;
        defer wire_buffer.head = save_head;
        const frame_header = wire_buffer.readFrameHeader() catch |err| {
            switch (err) {
                error.FrameHeaderReadFailure => return false,
            }
        };
        return (wire_buffer.end - save_head) >= (8 + frame_header.size);
    }

    pub fn readEOF(wire_buffer: *WireBuffer) !void {
        const byte = wire_buffer.readU8();
        if (byte != 0xCE) return error.ExpectedEOF;
    }

    fn writeEOF(wire_buffer: *WireBuffer) void {
        wire_buffer.writeU8(0xCE);
    }

    pub fn writeFrameHeader(wire_buffer: *WireBuffer, frame_type: FrameType, channel: u16, size: u32) void {
        wire_buffer.writeU8(@intFromEnum(frame_type));
        wire_buffer.writeU16(channel);
        wire_buffer.writeU32(size); // This will be overwritten later
    }

    pub fn updateFrameLength(wire_buffer: *WireBuffer) void {
        wire_buffer.writeEOF();
        const head = wire_buffer.head;
        wire_buffer.head = 3;
        wire_buffer.writeU32(@intCast(head - 8)); // size is head - header length (7 bytes) - frame end (1 bytes)
        wire_buffer.head = head;
    }

    pub fn readMethodHeader(wire_buffer: *WireBuffer) !MethodHeader {
        const class = wire_buffer.readU16();
        const method = wire_buffer.readU16();

        return MethodHeader{
            .class = class,
            .method = method,
        };
    }

    pub fn writeMethodHeader(wire_buffer: *WireBuffer, class: u16, method: u16) void {
        wire_buffer.writeU16(class);
        wire_buffer.writeU16(method);
    }

    pub fn readHeader(wire_buffer: *WireBuffer, frame_size: usize) !Header {
        const class = wire_buffer.readU16();
        const weight = wire_buffer.readU16();
        const body_size = wire_buffer.readU64();
        const property_flags = wire_buffer.readU16();
        const properties = wire_buffer.mem[wire_buffer.head .. wire_buffer.head + (frame_size - 14)];
        wire_buffer.head += (frame_size - 14);
        try wire_buffer.readEOF();

        return Header{
            .class = class,
            .weight = weight,
            .body_size = body_size,
            .property_flags = property_flags,
            .properties = properties,
        };
    }

    pub fn writeHeader(wire_buffer: *WireBuffer, channel: u16, size: u64, class: u16) void {
        wire_buffer.writeFrameHeader(.Header, channel, 0);
        wire_buffer.writeU16(class);
        wire_buffer.writeU16(0);
        wire_buffer.writeU64(size);
        wire_buffer.writeU16(0);
        wire_buffer.updateFrameLength();
    }

    pub fn readBody(wire_buffer: *WireBuffer, frame_size: usize) ![]u8 {
        const body = wire_buffer.mem[wire_buffer.head .. wire_buffer.head + frame_size];
        wire_buffer.head += frame_size;
        try wire_buffer.readEOF();

        return body;
    }

    pub fn writeBody(wire_buffer: *WireBuffer, channel: u16, body: []const u8) void {
        wire_buffer.writeFrameHeader(.Body, channel, 0);
        std.mem.copyForwards(u8, wire_buffer.mem[wire_buffer.head..], body);
        wire_buffer.head += body.len;
        wire_buffer.updateFrameLength();
    }

    pub fn writeHeartbeat(wire_buffer: *WireBuffer) void {
        wire_buffer.writeFrameHeader(.Heartbeat, 0, 0);
        wire_buffer.updateFrameLength();
    }

    pub fn readU8(wire_buffer: *WireBuffer) u8 {
        const r: u8 = wire_buffer.mem[wire_buffer.head];
        wire_buffer.head += 1;
        return r;
    }

    pub fn writeU8(wire_buffer: *WireBuffer, byte: u8) void {
        std.mem.writeInt(u8, &wire_buffer.mem[wire_buffer.head], byte, .big);
        wire_buffer.head += 1;
    }

    pub fn readU16(wire_buffer: *WireBuffer) u16 {
        const r = std.mem.readInt(u16, @ptrCast(&wire_buffer.mem[wire_buffer.head]), .big);
        wire_buffer.head += @sizeOf(u16);
        return r;
    }

    pub fn writeU16(wire_buffer: *WireBuffer, short: u16) void {
        std.mem.writeInt(u16, @ptrCast(&wire_buffer.mem[wire_buffer.head]), short, .big);
        wire_buffer.head += 2;
    }

    pub fn readU32(wire_buffer: *WireBuffer) u32 {
        const r = std.mem.readInt(u32, @ptrCast(&wire_buffer.mem[wire_buffer.head]), .big);
        wire_buffer.head += @sizeOf(u32);
        return r;
    }

    pub fn writeU32(wire_buffer: *WireBuffer, number: u32) void {
        std.mem.writeInt(u32, @ptrCast(&wire_buffer.mem[wire_buffer.head]), number, .big);
        wire_buffer.head += @sizeOf(u32);
    }

    pub fn readU64(wire_buffer: *WireBuffer) u64 {
        const r = std.mem.readInt(u64, @ptrCast(&wire_buffer.mem[wire_buffer.head]), .big);
        wire_buffer.head += @sizeOf(u64);
        return r;
    }

    pub fn writeU64(wire_buffer: *WireBuffer, number: u64) void {
        std.mem.writeInt(u64, @ptrCast(&wire_buffer.mem[wire_buffer.head]), number, .big);
        wire_buffer.head += @sizeOf(u64);
    }

    pub fn readBool(wire_buffer: *WireBuffer) bool {
        const r = wire_buffer.readU8();
        if (r == 0) return false;
        return true;
    }

    pub fn writeBool(wire_buffer: *WireBuffer, boolean: bool) void {
        wire_buffer.writeU8(if (boolean) 1 else 0);
    }

    pub fn readShortString(wire_buffer: *WireBuffer) []u8 {
        const length = wire_buffer.readU8();
        const array = wire_buffer.mem[wire_buffer.head .. wire_buffer.head + length];
        wire_buffer.head += length;
        return array;
    }

    pub fn writeShortString(wire_buffer: *WireBuffer, string: []const u8) void {
        wire_buffer.writeU8(@intCast(string.len));
        std.mem.copyForwards(u8, wire_buffer.mem[wire_buffer.head..], string);
        wire_buffer.head += string.len;
    }

    pub fn readLongString(wire_buffer: *WireBuffer) []u8 {
        const length = wire_buffer.readU32();
        const array = wire_buffer.mem[wire_buffer.head .. wire_buffer.head + length];
        wire_buffer.head += length;
        return array;
    }

    pub fn writeLongString(wire_buffer: *WireBuffer, string: []const u8) void {
        wire_buffer.writeU32(@intCast(string.len));
        std.mem.copyForwards(u8, wire_buffer.mem[wire_buffer.head..], string);
        wire_buffer.head += string.len;
    }

    // 1. Save the current read head
    // 2. Read the length (u32) of the table (the length of data after the u32 length)
    // 3. Until we've reached the end of the table
    //      3a. Read a table key
    //      3b. Read the value type for the key
    //      3c. Read that type
    pub fn readTable(wire_buffer: *WireBuffer) Table {
        const table_start = wire_buffer.head;
        const length = wire_buffer.readU32();

        while (wire_buffer.head - table_start < (length + @sizeOf(u32))) {
            _ = wire_buffer.readShortString();
            const t = wire_buffer.readU8();

            switch (t) {
                'F' => {
                    _ = wire_buffer.readTable();
                },
                't' => {
                    _ = wire_buffer.readBool();
                },
                's' => {
                    _ = wire_buffer.readShortString();
                },
                'S' => {
                    _ = wire_buffer.readLongString();
                },
                else => continue,
            }
        }

        return Table{
            .buf = WireBuffer.init(wire_buffer.mem[table_start..wire_buffer.head]),
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
    pub fn writeTable(wire_buffer: *WireBuffer, table: ?*Table) void {
        if (table) |t| {
            const table_bytes = t.buf.extent();
            std.mem.copyForwards(u8, wire_buffer.mem[wire_buffer.head..], table_bytes);
            wire_buffer.head += table_bytes.len;
        } else {
            wire_buffer.writeU32(0);
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
