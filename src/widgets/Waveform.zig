const Ctx = @import("Ctx.zig");
const Theme = @import("../Theme.zig");
const raylib = @cImport({
    @cInclude("raylib.h");
});

const std = @import("std");

const Self = @This();

downsampled_l: []f32 = &.{},
downsampled_r: []f32 = &.{},

// TODO: keep track of own down sampled audio buffer by adding new sampes each tick
// will have to keep in mind case of not enough new samples to down sample

pub fn draw(self: *Self, allocator: std.mem.Allocator, ctx: Ctx) !void {
    const half_height = @divTrunc(ctx.height, 2);
    const quarter_height = @divTrunc(half_height, 2);

    const num_of_samples: usize = @intCast(ctx.width);

    if (num_of_samples != self.downsampled_l.len) {
        if (self.downsampled_l.len != 0) {
            allocator.free(self.downsampled_l);
        }
        self.downsampled_l = try allocator.alloc(f32, num_of_samples);
    }
    if (num_of_samples != self.downsampled_r.len) {
        if (self.downsampled_r.len != 0) {
            allocator.free(self.downsampled_r);
        }
        self.downsampled_r = try allocator.alloc(f32, num_of_samples);
    }

    if (!ctx.isMouseButtonDown(raylib.MOUSE_BUTTON_LEFT)) {
        try ctx.audio_buffer_l.downSample(self.downsampled_l);
        try ctx.audio_buffer_r.downSample(self.downsampled_r);
    }

    const max_height = quarter_height;
    const padding = 4;

    drawWaveform(self.downsampled_l, half_height - max_height - padding, max_height, ctx.theme);
    drawWaveform(self.downsampled_r, half_height + max_height + padding, max_height, ctx.theme);
}

fn drawWaveform(samples: []const f32, y: i32, height: i32, theme: Theme) void {
    var x: i32 = 1;
    var prev_y_pos: i32 = y;
    var prev_y_neg: i32 = y;

    const bg_color = theme.amplitude_gradient.getColor(0.2);

    for (samples) |sample| {
        const length: i32 = @intFromFloat(@abs(sample) * @as(f32, @floatFromInt(height)));
        raylib.DrawLine(x, y - length, x, y + length, bg_color);
        raylib.DrawLine(x - 1, prev_y_pos, x, y + length, theme.primary);
        raylib.DrawLine(x - 1, prev_y_neg, x, y - length, theme.primary);
        prev_y_pos = y + length;
        prev_y_neg = y - length;
        x += 1;
    }
}
