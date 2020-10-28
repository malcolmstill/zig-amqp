// A WireBuffer is an abstraction over a slice that knows how
// to read and write the AMQP messages
const std = @import("std");
const Table = @import("table.zig").Table;

pub const WireBuffer = struct {
    // the current position in the buffer
    mem: []u8 = undefined,
    head: usize = 0, // TODO: do we even need head? Can we just update mem?

    const Self = @This();

    pub fn init(slice: []u8) WireBuffer {
        return WireBuffer {
            .mem = slice,
            .head = 0,
        };
    }

    // move head back to beginning of buffer
    pub fn reset(self: *Self) void {
        self.head = 0;
    }

    pub fn is_more_data(self: *Self) bool {
        return self.head < self.mem.len;
    }

    pub fn readFrameHeader(self: *Self) !FrameHeader {
        if (self.mem.len - self.head < @sizeOf(FrameHeader)) return error.FrameHeaderReadFailure;
        const frame_type = self.readU8();
        const channel = self.readU16();
        const size = self.readU32();

        return FrameHeader {
            .@"type" = @intToEnum(FrameType, frame_type),
            .channel = channel,
            .size = size,
        };
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

    pub fn readU8(self: *Self) u8 {
        const r = @ptrCast(u8, self.mem[self.head]);
        self.head += 1;
        return r;
    }

    pub fn readU16(self: *Self) u16 {
        const r = std.mem.readInt(u16, @ptrCast(*const [@sizeOf(u16)]u8, &self.mem[self.head]), .Big);
        self.head += @sizeOf(u16);
        return r;
    }

    pub fn readU32(self: *Self) u32 {
        const r = std.mem.readInt(u32, @ptrCast(*const [@sizeOf(u32)]u8, &self.mem[self.head]), .Big);
        self.head += @sizeOf(u32);
        return r;
    }

    pub fn readU64(self: *Self) u64 {
        const r = std.mem.readInt(u64, @ptrCast(*const [@sizeOf(u64)]u8, &self.mem[self.head]), .Big);
        self.head += @sizeOf(u64);
        return r;
    }

    pub fn readBool(self: *Self) bool {
        const r = self.readU8();
        if (r == 0) return false;
        return true;
    }

    pub fn readShortString(self: *Self) []u8 {
        const length = self.readU8();
        const array = self.mem[self.head..self.head+length];
        self.head += length;
        return array;
    }

    pub fn readLongString(self: *Self) []u8 {
        const length = self.readU32();
        const array = self.mem[self.head..self.head+length];
        self.head += length;
        return array;
    }

    // TODO: this is purely incrementing the read_head without returning anything useful
    pub fn readTable(self: *Self) Table {
        const saved_read_head = self.head;
        const length = self.readU32();

        while (self.head - saved_read_head < (length+@sizeOf(u32))) {
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
        const array: []u8 = self.mem[0..];

        return Table {
            .buf = WireBuffer.init(self.mem[saved_read_head..self.head]),
        };
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
    Method = 1,
    Header,
    Body,
    Heartbeat,
};

const MethodHeader = struct {
    class: u16 = 0,
    method: u16 = 0,
};