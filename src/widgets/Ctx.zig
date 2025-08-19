const AudioBuffer = @import("../AudioBuffer.zig");
const raylib = @cImport({
    @cInclude("raylib.h");
});

const Self = @This();

width: i32,
height: i32,
x_offset: i32,
y_offset: i32,
sample_rate: u32,
audio_buffer: AudioBuffer,

pub fn isMouseButtonDown(self: Self, button: i32) bool {
    if (!raylib.IsMouseButtonDown(button)) return false;

    const loc = raylib.GetMousePosition();
    const x: i32 = @intFromFloat(loc.x);
    const y: i32 = @intFromFloat(loc.y);

    return self.x_offset <= x and x <= self.x_offset + self.width and
        self.y_offset <= y and y <= self.y_offset + self.height;
}

pub fn getMousePosition(self: Self) raylib.Vector2 {
    const loc = raylib.GetMousePosition();
    return .{
        .x = loc.x - @as(f32, @floatFromInt(self.x_offset)),
        .y = loc.y - @as(f32, @floatFromInt(self.y_offset)),
    };
}
