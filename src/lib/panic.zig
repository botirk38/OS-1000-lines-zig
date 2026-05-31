const console = @import("console");
const io = @import("arch_console");

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    console.printf("\n[PANIC] " ++ fmt ++ "\n", args);

    io.shutdown();
}
