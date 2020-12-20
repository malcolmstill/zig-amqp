const Header = @import("wire.zig").Header;

pub const Message = struct {
    header: Header,
    body: []u8,
};
