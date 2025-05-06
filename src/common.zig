const std = @import("std");
const kernel = @import("kernel.zig");

/// Kernel console writer
const ConsoleWriter = struct {
    pub const Error = error{};

    pub fn write(_: ConsoleWriter, bytes: []const u8) Error!usize {
        for (bytes) |b| kernel.putChar(b);
        return bytes.len;
    }

    pub fn writer(self: ConsoleWriter) std.io.Writer(ConsoleWriter, Error, write) {
        return .{ .context = self };
    }
};

const console_writer = ConsoleWriter{};

/// Print formatted text to the kernel console
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    std.fmt.format(console_writer.writer(), fmt, args) catch unreachable;
}

/// Copy string from src to dest buffer, returns slice of copied data
pub fn stringCopy(dest: []u8, src: []const u8) []u8 {
    const len = @min(dest.len, src.len);
    std.mem.copy(u8, dest[0..len], src[0..len]);
    return dest[0..len];
}

/// Compare two strings lexicographically
pub fn stringCompare(a: []const u8, b: []const u8) std.math.Order {
    return std.mem.order(u8, a, b);
}
