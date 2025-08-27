const std = @import("std");
const builtin = @import("builtin");
const Wasapi = @import("Wasapi.zig");
const AudioBuffer = @import("AudioBuffer.zig");
const fft = @import("fft.zig");
const raylib = @import("raylib.zig");
const WidgetCtx = @import("widgets/Ctx.zig");
const Theme = @import("Theme.zig");
const ui = @import("ui.zig");

const fft_size = 8192;
const smoothing = 0.5;

var eq = @import("widgets/Eq.zig").Eq(fft_size, smoothing).init();
var sm = @import("widgets/Stereometer.zig"){};
var wf = @import("widgets/Waveform.zig"){};

const widgets = .{
    .{ .cols = 5, .widget = &eq },
    .{ .cols = 2, .widget = &sm },
    .{ .cols = 2, .widget = &wf },
};

const theme = Theme.main();

// --------------------------------------------------------------------------------
// topbar config

/// time needed to hover in topbar area for it to become visible
const topbar_hover_time_threshold_sec = 0.5;
/// current time hovering in topbar area
var topbar_hover_time: f32 = 0;

// signal boost
const max_gain = 100.0;
const min_gain = 1.0;
var gain: f32 = 1;
var gain_slider = ui.SliderH.init(min_gain, max_gain);

const max_opacity = 1.0;
const min_opacity = 0.1;
var opacity: f32 = 1;
var opacity_slider = ui.SliderH.init(min_opacity, max_opacity);

var is_borderless = false;

// --------------------------------------------------------------------------------

pub fn main() !void {
    var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_alloc.allocator();

    var wasapi = try Wasapi.init();
    defer wasapi.deinit();

    const cfg: AudioBuffer.Config = .{
        .duration_sec = 4,
        .sample_rate = @intCast(wasapi.pwfx.nSamplesPerSec),
    };

    var audio_buffer_l = try AudioBuffer.init(gpa, cfg);
    defer audio_buffer_l.deinit();
    var audio_buffer_r = try AudioBuffer.init(gpa, cfg);
    defer audio_buffer_r.deinit();

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

        var written: usize = 0;
        while (try wasapi.getBuffer()) |buffer| {
            defer buffer.deinit();
            var i: usize = 0;

            // NOTE: assume 32 bits per sample, and 2 channels

            while (i < buffer.value.len) : (i += 8) { // skip the right channel
                const sample_l = buffer.value[i .. i + 4];
                const sample_r = buffer.value[i + 4 .. i + 8];
                const sample_l_f32: f32 = @bitCast(std.mem.readInt(u32, sample_l[0..4], .little));
                const sample_r_f32: f32 = @bitCast(std.mem.readInt(u32, sample_r[0..4], .little));

                audio_buffer_l.writeSingle(std.math.clamp(sample_l_f32 * gain, -1.0, 1.0));
                audio_buffer_r.writeSingle(std.math.clamp(sample_r_f32 * gain, -1.0, 1.0));
                written += 1;
            }
        }

        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(theme.background);

        defer if (builtin.mode == .Debug) {
            raylib.DrawFPS(0, 0);
        };

        var total_x_offset: i32 = 0;

        const y_offset = 0;
        const w_height = height - y_offset;
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
                .num_of_new_samples = written,
                .audio_buffer_l = audio_buffer_l,
                .audio_buffer_r = audio_buffer_r,
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

        // draw top bar
        const slider_h = 10;
        const padding = 4;
        const topbar_height = slider_h + 2 * padding;

        const mouse_y = raylib.GetMouseY();

        const inside_topbar_area = mouse_y <= topbar_height or gain_slider.mouse_down_started;

        var topbar_visible: bool = false;
        if (inside_topbar_area) {
            topbar_hover_time += raylib.GetFrameTime();
            if (topbar_hover_time >= topbar_hover_time_threshold_sec) {
                topbar_visible = true;
            }
        } else {
            topbar_hover_time = 0.0;
            topbar_visible = false;
        }

        if (topbar_visible) {
            raylib.DrawRectangle(0, 0, width, topbar_height, theme.background);
            raylib.DrawLine(0, topbar_height, width, topbar_height, theme.background_light);

            const text = "Gain:";
            const text_width = padding + raylib.MeasureText(text, slider_h);
            raylib.DrawText(text, padding, padding, slider_h, theme.primary);

            const slider_w = @divFloor(width, 3);
            _ = try gain_slider.draw(theme, text_width + 4, padding, slider_w, slider_h, &gain);

            const changed = try opacity_slider.draw(theme, width - slider_w - 40, padding, slider_w, slider_h, &opacity);
            if (changed) {
                raylib.SetWindowOpacity(opacity);
            }

            const new_value = ui.drawCheckbox(theme, width - slider_h - padding, padding, slider_h, slider_h, is_borderless);
            if (new_value != is_borderless) {
                is_borderless = new_value;
                if (is_borderless) {
                    raylib.SetWindowState(raylib.FLAG_WINDOW_UNDECORATED);
                } else {
                    raylib.ClearWindowState(raylib.FLAG_WINDOW_UNDECORATED);
                }
            }
        }
    }

    raylib.CloseWindow();
}
