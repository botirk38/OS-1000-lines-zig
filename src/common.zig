//! Common utilities and core kernel functions
//! Pure utility functions without dependencies on other modules

const std = @import("std");
const console = @import("hal/console.zig");

/// Simple printf function using console HAL
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    console.printf(fmt, args);
}

/// Kernel panic function
pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    const debug_mod = @import("debug/panic.zig");
    debug_mod.panic(fmt, args);
}

/// Copy string from src to dest buffer, returns slice of copied data
pub fn stringCopy(dest: []u8, src: []const u8) []u8 {
    const len = @min(dest.len, src.len);
    @memcpy(dest[0..len], src[0..len]);
    return dest[0..len];
}

/// Compare two strings lexicographically
pub fn stringCompare(a: []const u8, b: []const u8) std.math.Order {
    return std.mem.order(u8, a, b);
}

/// Round up to the next multiple of alignment
pub fn alignUp(addr: u32, alignment: u32) u32 {
    return (addr + alignment - 1) & ~(alignment - 1);
}

/// Round down to the previous multiple of alignment
pub fn alignDown(addr: u32, alignment: u32) u32 {
    return addr & ~(alignment - 1);
}

/// Check if address is aligned to given boundary
pub fn isAligned(addr: u32, alignment: u32) bool {
    return (addr & (alignment - 1)) == 0;
}

