const std = @import("std");
const Wasapi = @import("Wasapi.zig");
const AudioBuffer = @import("AudioBuffer.zig");
const fft = @import("fft.zig");
const raylib = @cImport({
    @cInclude("raylib.h");
});
const WidgetCtx = @import("widgets/Ctx.zig");

var eq = @import("widgets/Eq.zig"){};
var wf = @import("widgets/Waveform.zig"){};

const widgets = .{
    .{ .cols = 1, .widget = &eq },
    .{ .cols = 1, .widget = &wf },
};

const boost = 10;

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

    comptime var total_cols = 0;
    inline for (widgets) |w| {
        total_cols += w.cols;
    }

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

        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(raylib.RAYWHITE);

        defer raylib.DrawFPS(0, 0);

        comptime var total_x_offset = 0;
        inline for (widgets) |w| {
            const cols = w.cols;
            const widget = w.widget;

            const y_offset = 0;
            const x_offset = total_x_offset;
            const w_height = height;
            const w_width = cols * width / total_cols;

            total_x_offset += w_width;

            const ctx: WidgetCtx = .{
                .height = w_height,
                .width = w_width,
                .x_offset = x_offset,
                .y_offset = y_offset,
                .sample_rate = wasapi.pwfx.nSamplesPerSec,
                .audio_buffer = audio_buffer,
            };

            raylib.BeginScissorMode(x_offset, y_offset, w_width, w_height);

            const cam: raylib.Camera2D = .{
                .offset = .{ .x = 0, .y = 0 },
                .target = .{
                    .x = -x_offset,
                    .y = -y_offset,
                },
                .rotation = 0,
                .zoom = 1,
            };

            raylib.BeginMode2D(cam);

            try widget.draw(gpa, ctx);

            raylib.EndMode2D();
            raylib.EndScissorMode();
        }
    }

    raylib.CloseWindow();
}
