const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

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

export fn kernel_main() noreturn {
    const bss_len = bss_end - bss;
    @memset(bss[0..bss_len], 0);

    const hello: []u8 = "Hello Kernel!\n";

    for (hello) |c| {
        put_char(c);
    }

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
fn put_char(ch: u8) void {
    sbi_call(.{ .a0 = ch, .a1 = 0, .a2 = 0, .a3 = 0, .a4 = 0, .a5 = 0, .fid = 0, .eid = 1 });
}

fn sbi_call(args: SbiCall) SbiRet {
    var err: u32 = undefined;
    var val: u32 = undefined;

    asm volatile ("ecall"
        : [err] "={a0}" (err),
          [val] "={a1}" (val),
        : [arg0] "{a0}" (args.arg0),
          [arg1] "{a1}" (args.arg1),
          [arg2] "{a2}" (args.arg2),
          [arg3] "{a3}" (args.arg3),
          [arg4] "{a4}" (args.arg4),
          [arg5] "{a5}" (args.arg5),
          [fid] "{a6}" (args.fid),
          [eid] "{a7}" (args.eid),
        : "memory"
    );

    return .{ .err = err, .val = val };
}
