const std = @import("std");
const console = @import("console");
const sbi = @import("sbi");

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    console.printf("\n[PANIC] " ++ fmt ++ "\n", args);

    sbi.shutdown();
}

pub fn assert(condition: bool, comptime message: []const u8) void {
    if (std.debug.runtime_safety and !condition) {
        panic("assertion failed: {s}", .{message});
    }
}

pub fn debug(comptime fmt: []const u8, args: anytype) void {
    if (std.debug.runtime_safety) {
        console.printf("[DEBUG] " ++ fmt ++ "\n", args);
    }
}
