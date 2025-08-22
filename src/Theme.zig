const raylib = @cImport({
    @cInclude("raylib.h");
});

const Color = raylib.Color;
const Self = @This();

primary: Color,
primary_dim: Color,
secondary: Color,
background: Color,
background_light: Color,

pub fn main() Self {
    return .{
        .primary = .{
            .r = 0,
            .g = 149,
            .b = 160,
            .a = 255,
        },
        .primary_dim = .{
            .r = 0,
            .g = 23,
            .b = 37,
            .a = @intFromFloat(255.0 * 0.74),
        },
        .secondary = .{
            .r = 251,
            .g = 190,
            .b = 255,
            .a = 255,
        },
        .background = .{
            .r = 0,
            .g = 12,
            .b = 23,
            .a = 255,
        },
        .background_light = .{
            .r = 35,
            .g = 53,
            .b = 70,
            .a = 255,
        },
    };
}
