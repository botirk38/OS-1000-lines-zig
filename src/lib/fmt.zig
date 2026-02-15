const console = @import("console");

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    console.printf(fmt, args);
}
