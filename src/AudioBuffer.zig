const std = @import("std");

const Self = @This();

buffer: []f32,
len: usize,
write_index: usize,
allocator: std.mem.Allocator,

pub const Config = struct {
    /// the sample rate of the audio source
    sample_rate: u32,
    /// number of seconds of audio to save
    duration_sec: u32,
};

pub fn init(allocator: std.mem.Allocator, config: Config) !Self {
    const len = config.duration_sec * config.sample_rate;
    const buffer = try allocator.alloc(f32, len);
    return .{
        .buffer = buffer,
        .len = len,
        .write_index = 0,
        .allocator = allocator,
    };
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.buffer);
}

pub fn write(self: *Self, buffer: []const f32) void {
    defer self.write_index = (self.write_index + buffer.len) % self.len;

    const slice = if (buffer.len > self.len)
        // if buffer is not big enough, only write the last part of the incomming data
        buffer[buffer.len - self.len .. buffer.len]
    else
        buffer;

    const available_till_end = self.len - self.write_index + 1;
    if (slice.len <= available_till_end) {
        @memcpy(self.buffer[self.write_index .. self.write_index + slice.len], slice);
        return;
    }

    // write to end of buffer
    const buffer_to_end = self.buffer[self.write_index..self.len];
    @memcpy(buffer_to_end, slice[0..buffer_to_end.len]);

    // write the rest at the start of the buffer again
    const rest_slice = slice[buffer_to_end.len..slice.len];
    @memcpy(self.buffer[0..rest_slice.len], rest_slice);
}

pub fn writeSingle(self: *Self, sample: f32) void {
    self.buffer[self.write_index] = sample;
    self.write_index = (self.write_index + 1) % self.len;
}

pub fn copy(self: Self, buffer: []f32, from: usize, to: usize) void {
    std.debug.assert(from < to);
    std.debug.assert(to - from == buffer.len);

    const res = buffer;

    const real_from = (self.write_index + from) % self.len;
    const real_to = (self.write_index + to) % self.len;

    if (real_from < real_to) {
        @memcpy(res, self.buffer[real_from..real_to]);
        return;
    }

    const buffer_to_end = self.buffer[real_from..self.len];
    @memcpy(res[0..buffer_to_end.len], buffer_to_end);

    const rest = self.buffer[0..real_to];
    @memcpy(res[buffer_to_end.len..], rest);
}

pub fn get(self: Self, index: usize) f32 {
    return self.buffer[(self.write_index + index) % self.len];
}
