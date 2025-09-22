//! Debug utilities - panic and assertion handling
//! Provides kernel panic functionality and debug assertions

const std = @import("std");
const console = @import("../hal/console.zig");
const sbi = @import("../platform/sbi.zig");

/// Kernel panic function - prints error and halts system
pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    console.printf("\n[PANIC] " ++ fmt ++ "\n", args);

    // Force a shutdown via SBI
    sbi.shutdown();
}

/// Debug assertion - panics if condition is false (debug builds only)
pub fn assert(condition: bool, comptime message: []const u8) void {
    if (std.debug.runtime_safety and !condition) {
        panic("assertion failed: {s}", .{message});
    }
}

/// Print debug information
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    if (std.debug.runtime_safety) {
        console.printf("[DEBUG] " ++ fmt ++ "\n", args);
    }
}

