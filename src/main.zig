const std = @import("std");
const Wasapi = @import("Wasapi.zig");
const AudioBuffer = @import("AudioBuffer.zig");

const raylib = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_alloc.allocator();

    var wasapi = try Wasapi.init();
    defer wasapi.deinit();

    var audio_buffer = try AudioBuffer.init(
        gpa,
        .{
            .duration_sec = 2,
            .sample_rate = wasapi.pwfx.nSamplesPerSec / wasapi.frameSize,
        },
    );
    defer audio_buffer.deinit();

    std.debug.print("{d}\n", .{audio_buffer.len});

    if (wasapi.pwfx.wBitsPerSample != 32) {
        return error.UnsupportedBitsPerSample;
    }
    if (wasapi.pwfx.nChannels != 2) {
        return error.OnlyTwoChannelDevicesSupported;
    }

    const width = 800;
    raylib.InitWindow(width, 450, "raylib [core] example - basic window");

    while (!raylib.WindowShouldClose()) {
        while (try wasapi.getBuffer()) |buffer| {
            defer buffer.deinit();
            var i: usize = 0;

            // NOTE: assume 32 bits per sample, and 2 channels

            while (i < buffer.value.len) : (i += 8) { // skip the right channel
                const sample = buffer.value[i .. i + 4]; // only take left channel
                const sample_f32: f32 = @bitCast(std.mem.readInt(u32, sample[0..4], .little));

                audio_buffer.writeSingle(sample_f32);
            }
        }

        const height = 100;
        const starty = 450 / 2;

        raylib.BeginDrawing();
        raylib.ClearBackground(raylib.RAYWHITE);

        const boost = 100;

        var x: i32 = 1;
        var i: usize = audio_buffer.len - width;
        for (0..width - 1) |_| {
            defer i += 1;

            const sample = audio_buffer.get(i);

            const length: i32 = @intFromFloat(sample * boost * @as(f32, @floatFromInt(height)));
            raylib.DrawLine(x, starty, x, starty + length, raylib.BLUE);
            x += 1;
        }

        raylib.EndDrawing();
    }

    raylib.CloseWindow();
}
