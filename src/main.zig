const std = @import("std");
const Wasapi = @import("Wasapi.zig");
const AudioBuffer = @import("AudioBuffer.zig");
const fft = @import("fft.zig");

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
            .sample_rate = @intCast(wasapi.pwfx.nSamplesPerSec / wasapi.frameSize),
        },
    );
    defer audio_buffer.deinit();

    if (wasapi.pwfx.wBitsPerSample != 32) {
        return error.UnsupportedBitsPerSample;
    }
    if (wasapi.pwfx.nChannels != 2) {
        return error.OnlyTwoChannelDevicesSupported;
    }

    const width = 800;
    raylib.InitWindow(width, 450, "raylib [core] example - basic window");

    const boost = 10;

    while (!raylib.WindowShouldClose()) {
        while (try wasapi.getBuffer()) |buffer| {
            defer buffer.deinit();
            var i: usize = 0;

            // NOTE: assume 32 bits per sample, and 2 channels

            while (i < buffer.value.len) : (i += 8) { // skip the right channel
                const sample = buffer.value[i .. i + 4]; // only take left channel
                const sample_f32: f32 = @bitCast(std.mem.readInt(u32, sample[0..4], .little));

                audio_buffer.writeSingle(std.math.clamp(sample_f32 * boost, -1.0, 1.0));
            }
        }

        const eq_samples = 1024;

        const eq_part = try audio_buffer.getCopy(gpa, audio_buffer.len - eq_samples, audio_buffer.len);
        defer gpa.free(eq_part);

        const amplitudes = try fft.amplitudes(gpa, eq_part);
        const bin_width = fft.freqBinWidth(eq_part.len, wasapi.pwfx.nSamplesPerSec);

        const height = 200;
        const starty = 450;

        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(raylib.RAYWHITE);

        var x: i32 = 1;

        for (amplitudes, 0..) |amp, i| {
            _ = i;
            _ = bin_width;

            const length: i32 = @intFromFloat(amp * @as(f32, @floatFromInt(height)));
            // if (amp > 1) {
            //     std.debug.print("freq: {d}, height: {d}, amp: {d}\n", .{ @as(f32, @floatFromInt(i)) * bin_width, length, amp });
            // }
            raylib.DrawLine(x, starty, x, starty - length, raylib.BLUE);
            x += 1;
        }

        // waveform drawing
        //
        // const height = 200;
        // const starty = 450 / 2;
        //
        // raylib.BeginDrawing();
        // defer raylib.EndDrawing();
        //
        // if (raylib.IsMouseButtonDown(raylib.MOUSE_BUTTON_LEFT)) {
        //     continue;
        // }
        //
        // raylib.ClearBackground(raylib.RAYWHITE);
        //
        // var x: i32 = 1;
        //
        // const down_sampled = try audio_buffer.downSample(gpa, width);
        // defer gpa.free(down_sampled);
        //
        // for (down_sampled) |sample| {
        //     const length: i32 = @intFromFloat(sample * @as(f32, @floatFromInt(height)));
        //     raylib.DrawLine(x, starty, x, starty + length, raylib.BLUE);
        //     x += 1;
        // }
    }

    raylib.CloseWindow();
}
