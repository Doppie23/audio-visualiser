const std = @import("std");
const Wasapi = @import("Wasapi.zig");

const raylib = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    var wasapi = try Wasapi.init();
    defer wasapi.deinit();

    if (wasapi.pwfx.wBitsPerSample != 32) {
        return error.UnsupportedBitsPerSample;
    }

    raylib.InitWindow(800, 450, "raylib [core] example - basic window");

    while (!raylib.WindowShouldClose()) {
        while (try wasapi.getBuffer()) |buffer| {
            const height = 100;
            const starty = 450 / 2;

            raylib.BeginDrawing();
            raylib.ClearBackground(raylib.RAYWHITE);

            const boost = 100;

            var x: i32 = 1;
            var i: usize = 0;

            // NOTE: assume 32 bits per sample
            while (i < buffer.len) : (i += 4) {
                const sample = buffer[i .. i + 4];
                const sample_f32: f32 = @bitCast(std.mem.readInt(u32, sample[0..4], .little));

                // Convert normalized sample (-1.0 to 1.0) to screen coordinates
                const length: i32 = @intFromFloat(sample_f32 * boost * @as(f32, @floatFromInt(height)));
                raylib.DrawLine(x, starty, x, starty + length, raylib.BLUE);
                x += 2;
            }
            // for (data) |sample| {
            //     const length: i32 = @divFloor((@as(i32, sample) - 128) * height, 255);
            // }

            raylib.EndDrawing();
        }
    }

    raylib.CloseWindow();
}
