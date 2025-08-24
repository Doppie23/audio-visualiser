const std = @import("std");
const Theme = @import("Theme.zig");
const raylib = @cImport({
    @cInclude("raylib.h");
});

const Self = @This();

/// 0 to 1
mouse_down_started: bool,
min: f32,
max: f32,

pub fn init(min: f32, max: f32) Self {
    return .{
        .mouse_down_started = false,
        .min = min,
        .max = max,
    };
}

pub fn draw(self: *Self, theme: Theme, x: i32, y: i32, width: i32, height: i32, value: *f32) !void {
    if (raylib.IsMouseButtonDown(raylib.MOUSE_BUTTON_LEFT)) {
        const loc = raylib.GetMousePosition();
        const mouse_x: i32 = @intFromFloat(loc.x);
        const mouse_y: i32 = @intFromFloat(loc.y);

        const in_bounds = x <= mouse_x and mouse_x <= x + width and
            y <= mouse_y and mouse_y <= y + height;

        if (in_bounds or self.mouse_down_started) {
            self.mouse_down_started = true;

            const progress = std.math.clamp(
                @as(f32, @floatFromInt((mouse_x - x))) / @as(f32, @floatFromInt(width)),
                0.0,
                1.0,
            );
            value.* = (self.max - self.min) * progress + self.min;
        }
    } else if (self.mouse_down_started) {
        self.mouse_down_started = false;
    }

    const progress = (value.* - self.min) / (self.max - self.min);

    raylib.DrawRectangleRoundedLines(
        .{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = @floatFromInt(width),
            .height = @floatFromInt(height),
        },
        0.5,
        10,
        theme.primary,
    );
    raylib.DrawRectangleRounded(
        .{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = @as(f32, @floatFromInt(width)) * progress,
            .height = @floatFromInt(height),
        },
        0.5,
        10,
        theme.primary,
    );

    var buf: [512]u8 = undefined;
    const text = try std.fmt.bufPrint(&buf, "{d:.1}\x00", .{value.*});

    raylib.DrawText(text.ptr, x + width + 4, y, height, theme.primary);
}
