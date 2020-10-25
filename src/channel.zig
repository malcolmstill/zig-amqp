const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const builtin = std.builtin;
const Connection = @import("connection.zig").Connection;

const Channel = struct {
    channel: u16 = 0,

    const Self = @This();

};

pub fn open(conn: Connection) !Channel {
    return Channel{
        .channel = 0, 
    };
}
