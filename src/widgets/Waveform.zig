const Ctx = @import("Ctx.zig");
const raylib = @cImport({
    @cInclude("raylib.h");
});

const std = @import("std");

const Self = @This();

cols: comptime_int,
// still_frame: ?[]const f32 = null,

pub fn draw(self: Self, allocator: std.mem.Allocator, ctx: Ctx) !void {
    _ = self;

    const starty = @divTrunc(ctx.height, 2);

    // TODO: bring back still frames
    // var down_sampled: []const f32 = undefined;
    //
    // if (ctx.isMouseButtonDown(raylib.MOUSE_BUTTON_LEFT) and self.still_frame != null) {
    //     // TODO: need a way to save state between draw calls
    //     // allocating does work, but not when using an arena that gets reset each frame
    //
    //     down_sampled = self.still_frame.?;
    // } else {
    //     if (self.still_frame) |old_frame| {
    //         allocator.free(old_frame);
    //     }
    //     // TODO: dont use an allocator, but use the same buffer each time
    //     down_sampled = try ctx.audio_buffer.downSample(allocator, @intCast(ctx.width));
    //     self.still_frame = down_sampled;
    // }

    var x: i32 = 1;

    // TODO: dont use an allocator, but use the same buffer each time
    const down_sampled = try ctx.audio_buffer.downSample(allocator, @intCast(ctx.width));
    defer allocator.free(down_sampled);

    for (down_sampled) |sample| {
        const length: i32 = @intFromFloat(sample * @as(f32, @floatFromInt(ctx.height)));
        raylib.DrawLine(x, starty, x, starty + length, raylib.BLUE);
        x += 1;
    }
}
