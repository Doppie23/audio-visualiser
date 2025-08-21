const std = @import("std");
const Theme = @import("Theme.zig");
const raylib = @cImport({
    @cInclude("raylib.h");
});

const Self = @This();

/// 0 to 1
progress: f32,
mouse_down_started: bool,

pub fn init(default_progress: f32) Self {
    return .{
        .progress = default_progress,
        .mouse_down_started = false,
    };
}

pub fn draw(self: *Self, theme: Theme, x: i32, y: i32, width: i32, height: i32) bool {
    if (raylib.IsMouseButtonDown(raylib.MOUSE_BUTTON_LEFT)) {
        const loc = raylib.GetMousePosition();
        const mouse_x: i32 = @intFromFloat(loc.x);
        const mouse_y: i32 = @intFromFloat(loc.y);

        const in_bounds = x <= mouse_x and mouse_x <= x + width and
            y <= mouse_y and mouse_y <= y + height;

        if (in_bounds or self.mouse_down_started) {
            self.mouse_down_started = true;
            self.progress = std.math.clamp(
                @as(f32, @floatFromInt((mouse_x - x))) / @as(f32, @floatFromInt(width)),
                0.0,
                1.0,
            );
        }
    } else if (self.mouse_down_started) {
        self.mouse_down_started = false;
    }

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
            .width = @as(f32, @floatFromInt(width)) * self.progress,
            .height = @floatFromInt(height),
        },
        0.5,
        10,
        theme.primary,
    );

    return self.mouse_down_started;
}
