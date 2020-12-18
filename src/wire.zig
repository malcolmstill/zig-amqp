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
        return WireBuffer {
            .mem = slice,
            .head = 0,
            .end = 0,
        };
    }

    pub fn printSpan(self: *Self) void {
        for (self.mem[self.head..self.end]) |byte, i| {
            std.debug.warn("{x:0>2}", .{byte});
            if ((i + 1) % 8 == 0) std.debug.warn("\n", .{}) else std.debug.warn(" ", .{});
        }
        std.debug.warn("\n", .{});
    }

    // move head back to beginning of buffer
    pub fn reset(self: *Self) void {
        self.head = 0;
    }

    // Return slice of data between head and end
    pub fn span(self: *Self) []u8 {
        return self.mem[self.head..self.end];
    }

    // shift moves data between head and end to the front of mem
    pub fn shift(self: *Self) void {
        const new_end = self.end - self.head;
        mem.copy(u8, self.mem[0..new_end], self.mem[self.head..self.end]);
        self.head = 0;
        self.end = new_end;
    }

    // seek: move the reading `head` to a particular location
    pub fn seek(self: *Self, position: usize) !void {
        if (position > self.men.len - 1) return error.SeekOutOfBounds;
        self.head = position;
    }

    // Returns a slice of everything between the start of mem and head
    pub fn extent(self: *Self) []u8 {
        return self.mem[0..self.head];
    }

    // This doesn't return an error because we should use this after
    // reading into self.remaining() which already bounds amount.
    pub fn incrementEnd(self: *Self, amount: usize) void {
        self.end += amount;
    }

    // Returns a slice of everthing between end and the end of mem
    pub fn remaining(self: *Self) []u8 {
        return self.mem[self.end..];
    }

    pub fn is_more_data(self: *Self) bool {
        return self.head < self.mem.len;
    }

    pub fn readFrameHeader(self: *Self) !FrameHeader {
        if (self.end - self.head < @sizeOf(FrameHeader)) return error.FrameHeaderReadFailure;
        const frame_type = self.readU8();
        const channel = self.readU16();
        const size = self.readU32();
        // std.debug.warn("frame_type: {}, channel: {}, size: {}\n", .{frame_type, channel, size});

        return FrameHeader {
            .@"type" = @intToEnum(FrameType, frame_type),
            .channel = channel,
            .size = size,
        };
    }

    // Returns true if there is enough data read for
    // a full frame
    pub fn frameReady(self: *Self) bool {
        const save_head = self.head;
        const frame_header = self.readFrameHeader() catch |err| {
            switch (err) {
                error.FrameHeaderReadFailure => return false,
            }
        };
        if ((self.end - save_head) >= (8 + frame_header.size)) {
            return true;
        } else {
            return false;
        }
        self.head = save_head;
    }

    pub fn readEOF(self: *Self) !void {
        const byte = self.readU8();
        if (byte != 0xCE) return error.ExpectedEOF;
    }

    pub fn writeFrameHeader(self: *Self, frame_type: FrameType, channel: u16, size: u32) void {
        self.writeU8(@enumToInt(frame_type));
        self.writeU16(channel);
        self.writeU32(size); // This will be overwritten later
    }


    pub fn updateFrameLength(self: *Self) void {
        self.writeFrameEnd();
        const head = self.head;
        self.head = 3;
        self.writeU32(@intCast(u32, head-8)); // size is head - header length (7 bytes) - frame end (1 bytes)
        self.head = head;
    }

    fn writeFrameEnd(self: *Self) void {
        self.writeU8(0xCE);
    }

    pub fn readMethodHeader(self: *Self) !MethodHeader {
        if (self.mem.len - self.head < @sizeOf(MethodHeader)) return error.MethodHeaderReadFailure;
        const class = self.readU16();
        const method = self.readU16();

        return MethodHeader {
            .class = class,
            .method = method,
        };
    }

    pub fn writeMethodHeader(self: *Self, class: u16, method: u16) void {
        self.writeU16(class);
        self.writeU16(method);
    }

    pub fn readU8(self: *Self) u8 {
        const r = @ptrCast(u8, self.mem[self.head]);
        self.head += 1;
        return r;
    }

    pub fn writeU8(self: *Self, byte: u8) void {
        std.mem.writeInt(u8, &self.mem[self.head], byte, .Big);
        self.head += 1;
    }

    pub fn readU16(self: *Self) u16 {
        const r = std.mem.readInt(u16, @ptrCast(*const [@sizeOf(u16)]u8, &self.mem[self.head]), .Big);
        self.head += @sizeOf(u16);
        return r;
    }

    pub fn writeU16(self: *Self, short: u16) void {
        std.mem.writeInt(u16, @ptrCast(*[@sizeOf(u16)]u8, &self.mem[self.head]), short, .Big);
        self.head += 2;
    }

    pub fn readU32(self: *Self) u32 {
        const r = std.mem.readInt(u32, @ptrCast(*const [@sizeOf(u32)]u8, &self.mem[self.head]), .Big);
        self.head += @sizeOf(u32);
        return r;
    }

    pub fn writeU32(self: *Self, number: u32) void {
        std.mem.writeInt(u32, @ptrCast(*[@sizeOf(u32)]u8, &self.mem[self.head]), number, .Big);
        self.head += @sizeOf(u32);
    }    

    pub fn readU64(self: *Self) u64 {
        const r = std.mem.readInt(u64, @ptrCast(*const [@sizeOf(u64)]u8, &self.mem[self.head]), .Big);
        self.head += @sizeOf(u64);
        return r;
    }

    pub fn writeU64(self: *Self, number: u64) void {
        std.mem.writeInt(u64, @ptrCast(*[@sizeOf(u64)]u8, &self.mem[self.head]), number, .Big);
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
        const array = self.mem[self.head..self.head+length];
        self.head += length;
        return array;
    }

    pub fn writeShortString(self: *Self, string: []const u8) void {
        self.writeU8(@intCast(u8, string.len));
        std.mem.copy(u8, self.mem[self.head..], string);
        self.head += string.len;
    }

    pub fn readLongString(self: *Self) []u8 {
        const length = self.readU32();
        const array = self.mem[self.head..self.head+length];
        self.head += length;
        return array;
    }

    pub fn writeLongString(self: *Self, string: []const u8) void {
        self.writeU32(@intCast(u32, string.len));
        std.mem.copy(u8, self.mem[self.head..], string);
        self.head += string.len;
    }

    // TODO: this is purely incrementing the read_head without returning anything useful
    // 1. Save the current read head
    // 2. Read the length (u32) of the table (the length of data after the u32 length)
    // 3. Until we've reached the end of the table
    //      3a. Read a table key
    //      3b. Read the value type for the key
    //      3c. Read that type
    pub fn readTable(self: *Self) Table {
        const table_start = self.head;
        const length = self.readU32();

        while (self.head - table_start < (length+@sizeOf(u32))) {
            const key = self.readShortString();
            const t = self.readU8();
            // std.debug.warn("{}: ", .{ key });
            switch (t) {
                'F' => {
                    // std.debug.warn("\n\t", .{});
                    _ = self.readTable();
                },
                't' => {
                    const b = self.readBool();
                    // std.debug.warn("{}\n", .{ b });
                },
                's' => {
                    const s = self.readShortString();
                    // std.debug.warn("{}\n", .{ s });
                },
                'S' => {
                    const s = self.readLongString();
                    // std.debug.warn("{}\n", .{ s });
                },
                else => continue,
            }
        }

        return Table {
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
            std.mem.copy(u8, self.mem[self.head..], table_bytes);
            self.head += table_bytes.len;
        } else {
            self.writeU32(0);
        }
    }

    // Not sure if all of the following are required
    pub fn readArrayU8(self: *Self) []u8 {
        const array = self.mem[self.head..self.head+128];
        self.head += 128;
        return array;
    }

    pub fn readArray128U8(self: *Self) []u8 {
        const array = self.mem[self.head..self.head+128];
        self.head += 128;
        return array;
    }

    pub fn readOptionalArray128U8(self: *Self) ?[]u8 {
        const array = self.mem[self.head..self.head+128];
        self.head += 128;
        return array;
    }
};

const FrameHeader = struct {
    @"type": FrameType = .Method,
    channel: u16 = 0,
    size: u32 = 0,
};

const FrameType = enum(u8) {
    Method    = proto.FRAME_METHOD,
    Header    = proto.FRAME_HEADER,
    Body      = proto.FRAME_BODY,
    Heartbeat = proto.FRAME_HEARTBEAT,
};

const MethodHeader = struct {
    class: u16 = 0,
    method: u16 = 0,
};