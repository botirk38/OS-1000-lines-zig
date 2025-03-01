const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

const common = @import("common.zig");

pub export fn exit() noreturn {
    while (true) {}
}

pub fn putchar() void {
    // TODO: Will be implemented later
}

pub export fn start() callconv(.C) noreturn {
    asm volatile (
        \\mv sp, %[stack_top]
        \\call main
        \\call exit
        :
        : [stack_top] "r" (stack_top),
        : "memory"
    );
    unreachable;
}

pub export fn main() void {
    while (true) {}
}
