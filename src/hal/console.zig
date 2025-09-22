//! Hardware Abstraction Layer for console I/O
//! Provides a clean interface for console operations across different platforms

const sbi = @import("../platform/sbi.zig");

/// Put a single character to the console
pub fn putChar(c: u8) void {
    sbi.putChar(c);
}

/// Write a string to the console
pub fn writeString(str: []const u8) void {
    for (str) |c| {
        putChar(c);
    }
}

/// Simple formatted print function
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const result = @import("std").fmt.bufPrint(buf[0..], fmt, args) catch return;
    writeString(result);
}