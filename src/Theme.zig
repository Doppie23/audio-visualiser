const raylib = @cImport({
    @cInclude("raylib.h");
});

const Color = raylib.Color;
const Self = @This();

primary: Color,
secondary: Color,
background: Color,

pub fn main() Self {
    return .{
        .primary = .{
            .r = 0,
            .g = 255,
            .b = 238,
            .a = 255,
        },
        .secondary = .{
            .r = 251,
            .g = 190,
            .b = 255,
            .a = 255,
        },
        .background = .{
            .r = 4,
            .g = 0,
            .b = 44,
            .a = 255,
        },
    };
}
