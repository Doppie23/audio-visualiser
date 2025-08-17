const std = @import("std");
const wasapi = @import("wasapi.zig");

const raylib = @cImport({
    @cInclude("raylib.h");
});

const Sink = struct {
    /// returns true of the reading should stop
    pub fn onData(sink: *Sink, data: []const u8) bool {
        _ = sink;

        // TODO: draw data, dont care about thread for now

        // var acc: i64 = 0;
        // for (data) |sample| {
        //     acc += (@as(i64, sample) - 128);
        // }
        // std.debug.print("average {d}\n", .{@divFloor(acc, @as(i64, @intCast(data.len)))});
        // std.debug.print("{any}\n", .{data[0..10]});
        //

        const height = 100;
        const starty = 450 / 2;

        raylib.BeginDrawing();
        raylib.ClearBackground(raylib.RAYWHITE);

        const boost = 100;

        var x: i32 = 1;
        var i: usize = 0;
        // TODO: use format returned by wasapi
        while (i < data.len) : (i += 4) {
            const sample = data[i .. i + 4];
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

        // TODO: this might not be correct, we should read the value every tick and set a variable
        return raylib.WindowShouldClose();
    }
};

pub fn main() !void {
    raylib.InitWindow(800, 450, "raylib [core] example - basic window");

    var sink: Sink = .{};
    try wasapi.ReadAudio(&sink);

    // while (!raylib.WindowShouldClose()) {
    //     raylib.BeginDrawing();
    //     raylib.ClearBackground(raylib.RAYWHITE);
    //     raylib.DrawText("Congrats! You created your first window!", 190, 200, 20, raylib.LIGHTGRAY);
    //     raylib.EndDrawing();
    // }

    raylib.CloseWindow();
}
