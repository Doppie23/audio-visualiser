const std = @import("std");
const raylib = @import("raylib.zig");

const Color = raylib.Color;
const Self = @This();

primary: Color,
primary_dim: Color,
secondary: Color,
background: Color,
background_light: Color,
amplitude_gradient: Gradient,

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
        .amplitude_gradient = Gradient.init(&.{
            .{ .r = 0, .g = 23, .b = 37, .a = 191 },
            .{ .r = 7, .g = 40, .b = 60, .a = 191 },
            .{ .r = 205, .g = 76, .b = 115, .a = 191 },
            .{ .r = 255, .g = 150, .b = 112, .a = 191 },
        }),
    };
}

pub const Gradient = struct {
    points: []const Color,

    pub fn init(comptime points: []const Color) Gradient {
        comptime std.debug.assert(points.len > 1);
        return .{ .points = points };
    }

    pub fn getColor(self: Gradient, t: f32) Color {
        if (self.points.len == 0) {
            return Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
        }
        if (self.points.len == 1) {
            return self.points[0];
        }

        const clamped = std.math.clamp(t, 0.0, 1.0);

        const n = self.points.len - 1;
        const scaled = clamped * @as(f32, @floatFromInt(n));
        const idx: usize = @intFromFloat(std.math.floor(scaled));
        const frac = scaled - @as(f32, @floatFromInt(idx));

        if (idx >= n) {
            return self.points[n];
        }
        return lerp(self.points[idx], self.points[idx + 1], frac);
    }

    fn lerp(a: Color, b: Color, t: f32) Color {
        return Color{
            .r = a.r + @as(u8, @intFromFloat(@as(f32, @floatFromInt(@max(a.r, b.r) - @min(a.r, b.r))) * t)),
            .g = a.g + @as(u8, @intFromFloat(@as(f32, @floatFromInt(@max(a.g, b.g) - @min(a.g, b.g))) * t)),
            .b = a.b + @as(u8, @intFromFloat(@as(f32, @floatFromInt(@max(a.b, b.b) - @min(a.b, b.b))) * t)),
            .a = a.a + @as(u8, @intFromFloat(@as(f32, @floatFromInt(@max(a.a, b.a) - @min(a.a, b.a))) * t)),
        };
    }
};
