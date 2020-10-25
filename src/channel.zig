const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const builtin = std.builtin;
const Wire = @import("connection.zig").Wire;

const Channel = struct {
    channel: u16 = 0,

    const Self = @This();

};

pub fn open(conn: Wire) !Channel {
    return Channel{
        .channel = 0, 
    };
}
