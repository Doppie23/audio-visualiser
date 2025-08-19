const std = @import("std");
const math = std.math;
const pi = math.pi;
const Complex = math.Complex(f32);

// modifies the samples in place, returns a slice to the provided samples array with the amplitude values
pub fn amplitudes(allocator: std.mem.Allocator, samples: []f32) ![]f32 {
    const n = samples.len;

    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const complex = try arena.alloc(Complex, samples.len);
    for (samples, 0..) |sample, i| {
        complex[i] = .{ .re = sample, .im = 0 };
    }

    try cooleyTukey(arena, complex);

    const half_complex = complex[0 .. complex.len / 2];

    for (half_complex, 0..) |c, i| {
        samples[i] = 2 / @as(f32, @floatFromInt(n)) * c.magnitude();
    }

    return samples[0..half_complex.len];
}

pub fn freqBinWidth(num_of_samples: usize, sample_rate: u32) f32 {
    return @as(f32, @floatFromInt(sample_rate)) / @as(f32, @floatFromInt(num_of_samples));
}

fn cooleyTukey(arena: std.mem.Allocator, x: []Complex) !void {
    const n = x.len;

    if (n <= 1) return;

    const even_len = n / 2;
    var even = try arena.alloc(Complex, even_len);
    // dont free, assume the memory gets freed with the arena

    for (0..even_len) |i| {
        even[i] = x[i * 2];
    }

    const odd_len = even_len;
    var odd = try arena.alloc(Complex, odd_len);
    // again, dont free

    for (0..odd_len) |i| {
        odd[i] = x[i * 2 + 1];
    }

    try cooleyTukey(arena, even);
    try cooleyTukey(arena, odd);

    for (0..even_len) |k| {
        const t = (Complex{
            .re = 1.0 * math.cos(-2.0 * pi * @as(f32, @floatFromInt(k)) / @as(f32, @floatFromInt(n))),
            .im = 1.0 * math.sin(-2.0 * pi * @as(f32, @floatFromInt(k)) / @as(f32, @floatFromInt(n))),
        }).mul(odd[k]);

        x[k] = even[k].add(t);
        x[k + n / 2] = even[k].sub(t);
    }
}

test "test" {
    const alloc = std.testing.allocator;
    var x = [_]Complex{
        Complex{ .re = 1, .im = 0 },
        Complex{ .re = 2, .im = 0 },
        Complex{ .re = 3, .im = 0 },
        Complex{ .re = 4, .im = 0 },
    };

    const arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    try cooleyTukey(arena.allocator(), &x);

    // TODO: actual test
    for (x) |c| {
        std.debug.print("re: {d}, im: {d}\n", .{ c.re, c.im });
    }
}
