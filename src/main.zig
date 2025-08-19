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
    const height = 450;
    raylib.InitWindow(width, height, "raylib [core] example - basic window");

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

        const eq_samples = 4096;

        const eq_part = try audio_buffer.getCopy(gpa, audio_buffer.len - eq_samples, audio_buffer.len);
        defer gpa.free(eq_part);

        const amplitudes = try fft.amplitudes(gpa, eq_part);
        const bin_width = fft.freqBinWidth(eq_part.len, wasapi.pwfx.nSamplesPerSec);

        const vis_height = 200;

        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(raylib.RAYWHITE);

        // var x: i32 = 1;

        if (raylib.IsMouseButtonDown(raylib.MOUSE_BUTTON_LEFT)) {
            const pos = raylib.GetMousePosition();

            const freq = xToFreq(pos.x, 20, 20000, width);
            const x: i32 = @intFromFloat(pos.x);
            const y: i32 = 200;

            // max size is 6, "20000\0"
            var buf: [6]u8 = undefined;
            const text = try std.fmt.bufPrint(&buf, "{d}\x00", .{@trunc(freq)});

            raylib.DrawLine(x, 0, x, height, raylib.GRAY);
            raylib.DrawText(text.ptr, x + 2, y, 12, raylib.GRAY);
        }

        var prev_x: i32 = 0;
        var prev_y: i32 = 0;

        for (amplitudes, 0..) |amp, i| {
            const min_db = -80.0;
            const db_amp = 20.0 * std.math.log10(amp + 1e-10); // Add small value to avoid log(0)
            const clamped_db = @max(min_db, db_amp);
            const normalized_db = (clamped_db - min_db) / (0.0 - min_db);
            const length: i32 = @intFromFloat(normalized_db * @as(f32, @floatFromInt(vis_height)));

            const freq = @as(f32, @floatFromInt(i)) * bin_width;
            const x = freqToX(freq, 20, 20000, width);
            const y = height - length;

            // if (amp > 1) {
            //     std.debug.print("freq: {d}, vis_height: {d}, amp: {d}\n", .{ @as(f32, @floatFromInt(i)) * bin_width, length, amp });
            // }

            raylib.DrawLine(prev_x, prev_y, x, y, raylib.BLUE);
            prev_x = x;
            prev_y = y;
        }

        // waveform drawing
        //
        // const vis_height = 200;
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
        //     const length: i32 = @intFromFloat(sample * @as(f32, @floatFromInt(vis_height)));
        //     raylib.DrawLine(x, starty, x, starty + length, raylib.BLUE);
        //     x += 1;
        // }
    }

    raylib.CloseWindow();
}

fn freqToX(f: f32, f_min: f32, f_max: f32, width: i32) i32 {
    if (f == 0) {
        return 0;
    }
    const log_min = std.math.log10(f_min);
    const log_max = std.math.log10(f_max);
    const log_f = std.math.log10(f);
    const x = (log_f - log_min) / (log_max - log_min) * @as(f32, @floatFromInt(width));
    return @intFromFloat(x);
}

fn xToFreq(x: f32, f_min: f32, f_max: f32, width: i32) f32 {
    const log_min = std.math.log10(f_min);
    const log_max = std.math.log10(f_max);
    const log_f = (x / @as(f32, @floatFromInt(width))) * (log_max - log_min) + log_min;
    return std.math.pow(f32, 10, log_f);
}
