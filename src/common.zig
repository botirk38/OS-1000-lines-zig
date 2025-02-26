const kernel = @import("kernel.zig");
const std = @import("std");

// Writer implementation for kernel console output
const Writer = struct {
    pub const Error = error{};

    pub fn write(_: @This(), bytes: []const u8) Error!usize {
        for (bytes) |b| kernel.put_char(b);
        return bytes.len;
    }

    // Provide a writer interface compatible with std.fmt
    pub fn writer(self: @This()) std.io.Writer(@This(), Error, write) {
        return .{ .context = self };
    }
};

// Single global console writer
const console = Writer{};

/// Print formatted text to the console
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    std.fmt.format(console.writer(), fmt, args) catch unreachable;
}

// Copy a string to a fixed-size buffer
pub fn stringCopy(dest: []u8, src: []const u8) []u8 {
    const len = @min(dest.len, src.len);
    std.mem.copy(u8, dest[0..len], src[0..len]);
    return dest[0..len];
}

pub fn stringCompare(a: []const u8, b: []const u8) std.math.Order {
    return std.mem.order(u8, a, b);
}
