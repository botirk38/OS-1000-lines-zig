const console = @import("console");
const arch = @import("arch");

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    console.printf("\n[PANIC] " ++ fmt ++ "\n", args);

    arch.Sbi.shutdown();
}
