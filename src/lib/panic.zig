const console = @import("console");
const sbi = @import("sbi");

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    console.printf("\n[PANIC] " ++ fmt ++ "\n", args);

    sbi.shutdown();
}
