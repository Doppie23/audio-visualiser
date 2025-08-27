const std = @import("std");
const Ctx = @import("Ctx.zig");
const raylib = @import("../raylib.zig");

const Self = @This();

// number of points to draw
const size = 1024;

const dot_radius = 1;

pub fn draw(self: Self, allocator: std.mem.Allocator, ctx: Ctx) !void {
    _ = .{ self, allocator };

    const cx = @divFloor(ctx.width, 2);
    const cy = @divFloor(ctx.height, 2);

    // square aspect ratio
    const min: f32 = @floatFromInt(@min(ctx.height, ctx.width));

    const height: f32 = min;
    const width: f32 = height;

    const margin = min / 10;
    const radius = width / 2 - margin;

    // bg overlay
    const radius_int: i32 = @as(i32, @intFromFloat(radius));

    raylib.DrawLine(cx, cy - radius_int, cx + radius_int, cy, ctx.theme.background_light);
    raylib.DrawLine(cx + radius_int, cy, cx, cy + radius_int, ctx.theme.background_light);
    raylib.DrawLine(cx, cy + radius_int, cx - radius_int, cy, ctx.theme.background_light);
    raylib.DrawLine(cx - radius_int, cy, cx, cy - radius_int, ctx.theme.background_light);

    const half_r = @divFloor(radius_int, 2);
    raylib.DrawLine(cx - half_r, cy + half_r, cx + half_r, cy - half_r, ctx.theme.background_light);
    raylib.DrawLine(cx - half_r, cy - half_r, cx + half_r, cy + half_r, ctx.theme.background_light);

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const l = ctx.audio_buffer_l.get(ctx.audio_buffer_l.len - size + i);
        const r = ctx.audio_buffer_r.get(ctx.audio_buffer_r.len - size + i);

        const x = (l - r) / 2;
        const y = (l + r) / 2;

        const c = clampDiamond(x * radius, y * radius, radius);

        const sx = cx + @as(i32, @intFromFloat(c.x));
        const sy = cy + @as(i32, @intFromFloat(c.y));

        raylib.DrawCircle(sx, sy, dot_radius, ctx.theme.primary);
    }
}

fn clampDiamond(x: f32, y: f32, r: f32) struct { x: f32, y: f32 } {
    const m = @abs(x) + @abs(y);
    if (m <= r or m == 0) return .{ .x = x, .y = y };
    const s = r / m;
    return .{ .x = x * s, .y = y * s };
}
