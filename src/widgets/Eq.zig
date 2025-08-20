const Ctx = @import("Ctx.zig");
const raylib = @cImport({
    @cInclude("raylib.h");
});

const std = @import("std");
const fft = @import("../fft.zig");

const Self = @This();

const fft_size = 4096;

const f_min: comptime_float = 20.0;
const f_max: comptime_float = 20000.0;

var eq_part: [fft_size]f32 = undefined;

// https://numpy.org/doc/stable/reference/generated/numpy.hanning.html
const hann_table = blk: {
    @setEvalBranchQuota(fft_size * 2);

    const M: f32 = @floatFromInt(fft_size);
    var table: [fft_size]f32 = undefined;

    for (&table, 0..) |*b, n| {
        b.* = 0.5 - 0.5 * std.math.cos(2 * std.math.pi * @as(f32, @floatFromInt(n)) / (M - 1));
    }
    break :blk table;
};

pub fn draw(self: Self, allocator: std.mem.Allocator, ctx: Ctx) !void {
    _ = self;

    if (ctx.isMouseButtonDown(raylib.MOUSE_BUTTON_LEFT)) {
        const pos = ctx.getMousePosition();

        const freq = xToFreq(pos.x, ctx.width);
        const x: i32 = @intFromFloat(pos.x);
        const y: i32 = 20;

        // max size is 6, "20000\0"
        var buf: [8]u8 = undefined;
        const text = try std.fmt.bufPrint(&buf, "{d}hz\x00", .{@trunc(freq)});
        const font_size = 16;

        raylib.DrawLine(x, 0, x, ctx.height, raylib.GRAY);
        const text_width = raylib.MeasureText(text.ptr, font_size);

        var text_x = x + 2;
        if (text_x + text_width > ctx.width) {
            text_x = x - text_width - 2;
        }

        raylib.DrawText(text.ptr, text_x, y, font_size, raylib.GRAY);
    }

    ctx.audio_buffer.copy(&eq_part, ctx.audio_buffer.len - fft_size, ctx.audio_buffer.len);

    // smooth using hann table
    for (&eq_part, hann_table) |*e, h| {
        e.* *= h;
    }

    const amplitudes = try fft.amplitudes(allocator, &eq_part);
    const bin_width = fft.freqBinWidth(eq_part.len, ctx.sample_rate);

    var prev_x: i32 = 0;
    var prev_y: i32 = ctx.height;

    for (amplitudes, 0..) |amp, i| {
        const freq = @as(f32, @floatFromInt(i)) * bin_width;

        // audio amplitude log scaling
        //
        // NOTE:
        // This might not all be technically correct, but it looks
        // decently close to other visualizers.

        const freq_comp = std.math.sqrt(freq + 1.0);
        const boosted_amp = amp * freq_comp;

        const db_amp = 20.0 * std.math.log10(boosted_amp + 1e-10); // Add small value to avoid log(0)
        const normalized_db = @max(0.0, (db_amp + 60.0) / 60.0); // Normalize -60dB to 0dB range
        const length: i32 = @intFromFloat(normalized_db * @as(f32, @floatFromInt(ctx.height)));

        const x = freqToX(freq, ctx.width);
        const y = ctx.height - length;

        raylib.DrawLine(prev_x, prev_y, x, y, raylib.BLUE);
        prev_x = x;
        prev_y = y;
    }
}

fn freqToX(f: f32, width: i32) i32 {
    if (f == 0) {
        return 0;
    }
    const log_min = std.math.log10(f_min);
    const log_max = std.math.log10(f_max);
    const log_f = std.math.log10(f);
    const x = (log_f - log_min) / (log_max - log_min) * @as(f32, @floatFromInt(width));
    return @intFromFloat(x);
}

fn xToFreq(x: f32, width: i32) f32 {
    const log_min = std.math.log10(f_min);
    const log_max = std.math.log10(f_max);
    const log_f = (x / @as(f32, @floatFromInt(width))) * (log_max - log_min) + log_min;
    return std.math.pow(f32, 10, log_f);
}
