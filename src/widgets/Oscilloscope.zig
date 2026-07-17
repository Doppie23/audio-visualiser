const AudioBuffer = @import("../AudioBuffer.zig");
const Ctx = @import("Ctx.zig");
const Theme = @import("../Theme.zig");
const raylib = @import("raylib");

const std = @import("std");

const Self = @This();

smoothing: f32,
smoothed: ?[]f32 = null,

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    if (self.smoothed) |s| {
        allocator.free(s);
    }
}

pub fn draw(self: *Self, allocator: std.mem.Allocator, ctx: Ctx) !void {
    _ = .{self};
    const len = ctx.audio_buffer_l.len;

    if (self.smoothed == null or self.smoothed.?.len != ctx.width) {
        if (self.smoothed != null) {
            allocator.free(self.smoothed.?);
        }
        self.smoothed = try allocator.alloc(f32, @intCast(ctx.width));
        @memset(self.smoothed.?, 0);
    }

    // last sample where the sign (+/-) changes, i.e. the last sample in the buffer that is around 0.0
    //           *
    //      *         *
    //   *               *
    // *                   *                   *
    //                       *               * ^- `last_sample`
    //                          *         *
    //                               *
    const last_sample: usize = blk: {
        var i: usize = len - 1;
        var last_sign: bool = ctx.audio_buffer_l.get(i) >= 0.0;

        while (i > 0) : (i -= 1) {
            const sign = ctx.audio_buffer_l.get(i) >= 0.0;
            defer last_sign = sign;

            if (last_sign != sign and !sign) {
                break :blk i + 1;
            }
        }
        break :blk @intCast(ctx.width - 1);
    };

    const u_width: usize = @intCast(ctx.width);
    const to = @max(last_sample, u_width);
    const from = to - u_width;

    var i: usize = 0;
    while (i < (to - from)) : (i += 1) {
        const sample = ctx.audio_buffer_l.get(from + i);
        self.smoothed.?[i] = self.smoothing * self.smoothed.?[i] + (1.0 - self.smoothing) * sample;
    }

    const half_height = @divTrunc(ctx.height, 2);

    drawWaveform(self.smoothed.?, half_height, ctx.width, half_height, ctx.theme);
}

fn drawWaveform(buffer: []f32, y: i32, width: i32, half_height: i32, theme: Theme) void {
    std.debug.assert(buffer.len == width);

    var prev_x: i32 = 0;
    var prev_y: i32 = y;

    for (buffer, 0..) |sample, x| {
        const length: i32 = @intFromFloat(sample * @as(f32, @floatFromInt(half_height)));
        raylib.DrawLine(prev_x, prev_y, @intCast(x), y + length, theme.primary);
        prev_x = @intCast(x);
        prev_y = y + length;
    }
}
