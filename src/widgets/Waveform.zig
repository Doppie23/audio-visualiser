const Ctx = @import("Ctx.zig");
const raylib = @cImport({
    @cInclude("raylib.h");
});

const std = @import("std");

const Self = @This();

down_sample_buffer: ?[]f32 = null,

// TODO: keep track of own down sampled audio buffer by adding new sampes each tick
// will have to keep in mind case of not enough new samples to down sample

pub fn draw(self: *Self, allocator: std.mem.Allocator, ctx: Ctx) !void {
    const starty = @divTrunc(ctx.height, 2);

    const num_of_samples: usize = @intCast(ctx.width);

    if (self.down_sample_buffer == null or num_of_samples != self.down_sample_buffer.?.len) {
        if (self.down_sample_buffer) |old| {
            allocator.free(old);
        }
        self.down_sample_buffer = try allocator.alloc(f32, num_of_samples);
    }

    if (!ctx.isMouseButtonDown(raylib.MOUSE_BUTTON_LEFT)) {
        try ctx.audio_buffer.downSample(self.down_sample_buffer.?);
    }

    raylib.DrawLine(0, starty, ctx.width, starty, ctx.theme.primary);

    var x: i32 = 1;

    for (self.down_sample_buffer.?) |sample| {
        const length: i32 = @intFromFloat(sample * @as(f32, @floatFromInt(ctx.height)));
        raylib.DrawLine(x, starty - length, x, starty + length, ctx.theme.primary);
        x += 1;
    }
}
