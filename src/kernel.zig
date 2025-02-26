const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });
const common = @import("common.zig");

const SbiCall = struct {
    a0: u32 = 0,
    a1: u32 = 0,
    a2: u32 = 0,
    a3: u32 = 0,
    a4: u32 = 0,
    a5: u32 = 0,
    fid: u32,
    eid: u32,
};

const SbiRet = struct {
    err: u32,
    value: u32,
};

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    // Get source file and line information using compiler builtins
    const src = @src();

    // Print panic message
    common.printf("PANIC: {s}:{d}: ", .{ src.file, src.line });
    common.printf(fmt, args);
    common.printf("\n", .{});

    // Halt the system
    while (true) {
        asm volatile ("wfi");
    }
}

export fn kernel_main() noreturn {
    const bss_len = bss_end - bss;
    @memset(bss[0..bss_len], 0);

    panic("booted!", .{});

    // This will never be reached
    common.printf("Unreachable here!\n", .{});

    while (true) asm volatile ("wfi");
}

export fn boot() linksection(".text.boot") callconv(.naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_main
        :
        : [stack_top] "r" (stack_top),
    );
}

pub fn put_char(ch: u8) void {
    _ = sbi_call(.{ .a0 = ch, .a1 = 0, .a2 = 0, .a3 = 0, .a4 = 0, .a5 = 0, .fid = 0, .eid = 1 });
}

fn sbi_call(args: SbiCall) SbiRet {
    var err: u32 = undefined;
    var val: u32 = undefined;
    asm volatile ("ecall"
        : [err] "={a0}" (err),
          [val] "={a1}" (val),
        : [arg0] "{a0}" (args.a0),
          [arg1] "{a1}" (args.a1),
          [arg2] "{a2}" (args.a2),
          [arg3] "{a3}" (args.a3),
          [arg4] "{a4}" (args.a4),
          [arg5] "{a5}" (args.a5),
          [fid] "{a6}" (args.fid),
          [eid] "{a7}" (args.eid),
        : "memory"
    );
    return .{ .err = err, .value = val };
}
