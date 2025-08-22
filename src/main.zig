const std = @import("std");
const Wasapi = @import("Wasapi.zig");
const AudioBuffer = @import("AudioBuffer.zig");
const fft = @import("fft.zig");
const raylib = @cImport({
    @cInclude("raylib.h");
});
const WidgetCtx = @import("widgets/Ctx.zig");
const Theme = @import("Theme.zig");
const Slider = @import("Slider.zig");

const fft_size = 8192;
const smoothing = 0.5;

var eq = @import("widgets/Eq.zig").Eq(fft_size, smoothing).init();
var wf = @import("widgets/Waveform.zig"){};

const widgets = .{
    .{ .cols = 5, .widget = &eq },
    .{ .cols = 2, .widget = &wf },
};

// signal boost
const max_boost = 10.0;
const min_boost = 1.0;

const theme = Theme.main();

pub fn main() !void {
    var boost: f32 = 5;
    var boost_slider = Slider.init(boost / max_boost);

    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_alloc.allocator();

    var wasapi = try Wasapi.init();
    defer wasapi.deinit();

    var audio_buffer = try AudioBuffer.init(
        gpa,
        .{
            .duration_sec = 4,
            .sample_rate = @intCast(wasapi.pwfx.nSamplesPerSec),
        },
    );
    defer audio_buffer.deinit();

    if (wasapi.pwfx.wBitsPerSample != 32) {
        return error.UnsupportedBitsPerSample;
    }
    if (wasapi.pwfx.nChannels != 2) {
        return error.OnlyTwoChannelDevicesSupported;
    }

    raylib.SetConfigFlags(raylib.FLAG_WINDOW_RESIZABLE);

    raylib.InitWindow(800, 200, "Audio Visualiser");

    comptime var total_cols = 0;
    inline for (widgets) |w| {
        total_cols += w.cols;
    }

    while (!raylib.WindowShouldClose()) {
        const height = raylib.GetRenderHeight();
        const width = raylib.GetRenderWidth();

        const slider_h = 10;

        const padding = 4;
        const text = "Boost:";
        const text_width = padding + raylib.MeasureText(text, slider_h);
        raylib.DrawText(text, padding, padding, slider_h, theme.primary);

        const changed = boost_slider.draw(theme, text_width + 4, padding, @divFloor(width, 4), slider_h);
        if (changed) {
            boost = @max(min_boost, max_boost * boost_slider.progress);
        }

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

        raylib.ClearBackground(theme.background);

        // defer raylib.DrawFPS(0, 0);

        var total_x_offset: i32 = 0;

        const y_offset = slider_h + padding;
        const w_height = height - slider_h;
        inline for (widgets) |w| {
            const cols = w.cols;
            const widget = w.widget;

            const x_offset = total_x_offset;
            const w_width = @divTrunc(cols * width, total_cols);

            total_x_offset += w_width;

            const ctx: WidgetCtx = .{
                .height = w_height,
                .width = w_width,
                .x_offset = x_offset,
                .y_offset = y_offset,
                .sample_rate = wasapi.pwfx.nSamplesPerSec,
                .audio_buffer = audio_buffer,
                .theme = theme,
            };

            raylib.BeginScissorMode(x_offset, y_offset, w_width, w_height);

            const cam: raylib.Camera2D = .{
                .offset = .{ .x = 0, .y = 0 },
                .target = .{
                    .x = -@as(f32, @floatFromInt(x_offset)),
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
