const std = @import("std");
const math = std.math;
const pi = math.pi;
const Complex = math.Complex(f32);

const Self = @This();

fba: std.heap.FixedBufferAllocator,
gpa: std.mem.Allocator,

pub fn init(comptime fft_size: comptime_int, gpa: std.mem.Allocator) !Self {
    const recursive_levels = math.log2(fft_size) + 1;
    const entries_needed = recursive_levels * fft_size;

    const buffer = try gpa.alloc(Complex, entries_needed);

    const fba = std.heap.FixedBufferAllocator.init(@ptrCast(buffer));

    return .{
        .fba = fba,
        .gpa = gpa,
    };
}

pub fn deinit(self: Self) void {
    self.gpa.free(self.fba.buffer);
}

// modifies the samples in place, returns a slice to the provided samples array with the amplitude values
pub fn amplitudes(self: *Self, samples: []f32) ![]f32 {
    self.fba.reset();

    const n = samples.len;

    var fba = self.fba.allocator();

    const complex = try fba.alloc(Complex, samples.len);
    for (samples, 0..) |sample, i| {
        complex[i] = .{ .re = sample, .im = 0 };
    }

    try self.cooleyTukey(complex);

    const half_complex = complex[0 .. complex.len / 2];

    for (half_complex, 0..) |c, i| {
        samples[i] = 2 / @as(f32, @floatFromInt(n)) * c.magnitude();
    }

    return samples[0..half_complex.len];
}

pub fn freqBinWidth(num_of_samples: usize, sample_rate: u32) f32 {
    return @as(f32, @floatFromInt(sample_rate)) / @as(f32, @floatFromInt(num_of_samples));
}

fn cooleyTukey(self: *Self, x: []Complex) !void {
    var fba = self.fba.allocator();
    const n = x.len;

    if (n <= 1) return;

    const even_len = n / 2;
    var even = try fba.alloc(Complex, even_len);

    for (0..even_len) |i| {
        even[i] = x[i * 2];
    }

    const odd_len = even_len;
    var odd = try fba.alloc(Complex, odd_len);

    for (0..odd_len) |i| {
        odd[i] = x[i * 2 + 1];
    }

    try self.cooleyTukey(even);
    try self.cooleyTukey(odd);

    for (0..even_len) |k| {
        const t = (Complex{
            .re = 1.0 * math.cos(-2.0 * pi * @as(f32, @floatFromInt(k)) / @as(f32, @floatFromInt(n))),
            .im = 1.0 * math.sin(-2.0 * pi * @as(f32, @floatFromInt(k)) / @as(f32, @floatFromInt(n))),
        }).mul(odd[k]);

        x[k] = even[k].add(t);
        x[k + n / 2] = even[k].sub(t);
    }
}

test "Cooley Tukey" {
    const alloc = std.testing.allocator;
    var xs = [_]Complex{
        Complex{ .re = 1, .im = 0 },
        Complex{ .re = 2, .im = 0 },
        Complex{ .re = 3, .im = 0 },
        Complex{ .re = 4, .im = 0 },
    };

    const expected = [_]Complex{
        Complex{ .re = 10, .im = 0 },
        Complex{ .re = -2, .im = 2 },
        Complex{ .re = -2, .im = 0 },
        Complex{ .re = -2, .im = -2 },
    };

    // use an arena for testing, instead of a FBA.
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    try cooleyTukey(arena.allocator(), &xs);

    for (xs, expected) |a, e| {
        try std.testing.expectApproxEqRel(a.re, e.re, 0.001);
        try std.testing.expectApproxEqRel(a.im, e.im, 0.001);
    }
}
