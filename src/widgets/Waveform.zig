const AudioBuffer = @import("../AudioBuffer.zig");
const Ctx = @import("Ctx.zig");
const Theme = @import("../Theme.zig");
const raylib = @import("raylib");

const std = @import("std");

const Self = @This();

/// down sample that does not have enough samples yet
/// to go into the down sampled buffer
const Intermediate = struct {
    sum_of_squares: f32,
    num_of_samples: usize,
};

intermediate_l: Intermediate = .{ .sum_of_squares = 0, .num_of_samples = 0 },
downsampled_l: ?AudioBuffer = null,

intermediate_r: Intermediate = .{ .sum_of_squares = 0, .num_of_samples = 0 },
downsampled_r: ?AudioBuffer = null,

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    _ = allocator;
    if (self.downsampled_l) |d| {
        d.deinit();
    }
    if (self.downsampled_r) |d| {
        d.deinit();
    }
}

pub fn draw(self: *Self, allocator: std.mem.Allocator, ctx: Ctx) !void {
    const half_height = @divTrunc(ctx.height, 2);
    const quarter_height = @divTrunc(half_height, 2);

    const num_of_samples: usize = @intCast(ctx.width);

    if (!ctx.isMouseButtonDown(raylib.MOUSE_BUTTON_LEFT)) {
        try downSampleNewData(allocator, ctx.audio_buffer_l, &self.downsampled_l, &self.intermediate_l, ctx.num_of_new_samples, num_of_samples);
        try downSampleNewData(allocator, ctx.audio_buffer_r, &self.downsampled_r, &self.intermediate_r, ctx.num_of_new_samples, num_of_samples);
    }

    const max_height = quarter_height;

    drawWaveform(self.downsampled_l.?, half_height - max_height, max_height, ctx.theme);
    drawWaveform(self.downsampled_r.?, half_height + max_height, max_height, ctx.theme);
}

fn downSampleNewData(allocator: std.mem.Allocator, audio_buffer: AudioBuffer, downsampled: *?AudioBuffer, intermediate: *Intermediate, new_samples: usize, size: usize) !void {
    if (downsampled.* == null or size != downsampled.*.?.len) {
        if (downsampled.*) |ab| {
            ab.deinit();
        }
        downsampled.* = try AudioBuffer.init(
            allocator,
            .{
                .sample_rate = 1,
                .duration_sec = @intCast(size),
            },
        );
        // we could downsample the entire audio buffer back into
        // the new downsampled buffer
        // but its easier to just set all elements to zero...
        @memset(downsampled.*.?.buffer, 0);
    } else {
        const buffer = audio_buffer;
        const down = &downsampled.*.?;

        const samples_in_down_sample = @divFloor(buffer.len, down.len);

        // go through all new samples and downsample them

        var i: usize = buffer.len - new_samples;
        while (i < buffer.len) : (i += 1) {
            const sample = buffer.get(i);

            intermediate.sum_of_squares += sample * sample;
            intermediate.num_of_samples += 1;

            if (intermediate.num_of_samples >= samples_in_down_sample) {
                const mean_square = intermediate.sum_of_squares / @as(f32, @floatFromInt(intermediate.num_of_samples));
                down.writeSingle(@sqrt(mean_square));
                intermediate.* = .{ .num_of_samples = 0, .sum_of_squares = 0 };
            }
        }
    }
}

fn drawWaveform(buffer: AudioBuffer, y: i32, height: i32, theme: Theme) void {
    var x: i32 = 1;
    var prev_y_pos: i32 = y;
    var prev_y_neg: i32 = y;

    const bg_color = theme.amplitude_gradient.getColor(0.2);

    var i: usize = 0;
    while (i < buffer.len) : (i += 1) {
        const sample = buffer.get(i);
        const length: i32 = @intFromFloat(@abs(sample) * @as(f32, @floatFromInt(height)));
        raylib.DrawLine(x, y - length, x, y + length, bg_color);
        raylib.DrawLine(x - 1, prev_y_pos, x, y + length, theme.primary);
        raylib.DrawLine(x - 1, prev_y_neg, x, y - length, theme.primary);
        prev_y_pos = y + length;
        prev_y_neg = y - length;
        x += 1;
    }
}
