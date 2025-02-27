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

const TrapFrame = packed struct {
    ra: u32,
    gp: u32,
    tp: u32,
    t0: u32,
    t1: u32,
    t2: u32,
    t3: u32,
    t4: u32,
    t5: u32,
    t6: u32,
    a0: u32,
    a1: u32,
    a2: u32,
    a3: u32,
    a4: u32,
    a5: u32,
    a6: u32,
    a7: u32,
    s0: u32,
    s1: u32,
    s2: u32,
    s3: u32,
    s4: u32,
    s5: u32,
    s6: u32,
    s7: u32,
    s8: u32,
    s9: u32,
    s10: u32,
    s11: u32,
    sp: u32,
};

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

// Read a CSR register
fn readCsr(comptime reg: []const u8) u32 {
    return asm volatile ("csrr %[ret], " ++ reg
        : [ret] "=r" (-> u32),
    );
}

// Write to a CSR register
fn writeCsr(comptime reg: []const u8, value: u32) void {
    asm volatile ("csrw " ++ reg ++ ", %[val]"
        :
        : [val] "r" (value),
    );
}

// Handle the trap/exception
export fn handleTrap(frame: *TrapFrame) callconv(.C) void {
    const scause = readCsr("scause");
    const stval = readCsr("stval");
    const user_pc = readCsr("sepc");

    // Print some relevant registers from the frame
    panic("trap: scause={x}, stval={x}, sepc={x}, ra={x}, sp={x}", .{ scause, stval, user_pc, frame.ra, frame.sp });
}

// Exception entry point
fn kernelEntry() callconv(.Naked) void {
    asm volatile (
        \\csrw sscratch, sp
        \\addi sp, sp, -4 * 31
        \\sw ra,  4 * 0(sp)
        \\sw gp,  4 * 1(sp)
        \\sw tp,  4 * 2(sp)
        \\sw t0,  4 * 3(sp)
        \\sw t1,  4 * 4(sp)
        \\sw t2,  4 * 5(sp)
        \\sw t3,  4 * 6(sp)
        \\sw t4,  4 * 7(sp)
        \\sw t5,  4 * 8(sp)
        \\sw t6,  4 * 9(sp)
        \\sw a0,  4 * 10(sp)
        \\sw a1,  4 * 11(sp)
        \\sw a2,  4 * 12(sp)
        \\sw a3,  4 * 13(sp)
        \\sw a4,  4 * 14(sp)
        \\sw a5,  4 * 15(sp)
        \\sw a6,  4 * 16(sp)
        \\sw a7,  4 * 17(sp)
        \\sw s0,  4 * 18(sp)
        \\sw s1,  4 * 19(sp)
        \\sw s2,  4 * 20(sp)
        \\sw s3,  4 * 21(sp)
        \\sw s4,  4 * 22(sp)
        \\sw s5,  4 * 23(sp)
        \\sw s6,  4 * 24(sp)
        \\sw s7,  4 * 25(sp)
        \\sw s8,  4 * 26(sp)
        \\sw s9,  4 * 27(sp)
        \\sw s10, 4 * 28(sp)
        \\sw s11, 4 * 29(sp)
        \\csrr a0, sscratch
        \\sw a0, 4 * 30(sp)
        \\mv a0, sp
        \\call handleTrap
        \\lw ra,  4 * 0(sp)
        \\lw gp,  4 * 1(sp)
        \\lw tp,  4 * 2(sp)
        \\lw t0,  4 * 3(sp)
        \\lw t1,  4 * 4(sp)
        \\lw t2,  4 * 5(sp)
        \\lw t3,  4 * 6(sp)
        \\lw t4,  4 * 7(sp)
        \\lw t5,  4 * 8(sp)
        \\lw t6,  4 * 9(sp)
        \\lw a0,  4 * 10(sp)
        \\lw a1,  4 * 11(sp)
        \\lw a2,  4 * 12(sp)
        \\lw a3,  4 * 13(sp)
        \\lw a4,  4 * 14(sp)
        \\lw a5,  4 * 15(sp)
        \\lw a6,  4 * 16(sp)
        \\lw a7,  4 * 17(sp)
        \\lw s0,  4 * 18(sp)
        \\lw s1,  4 * 19(sp)
        \\lw s2,  4 * 20(sp)
        \\lw s3,  4 * 21(sp)
        \\lw s4,  4 * 22(sp)
        \\lw s5,  4 * 23(sp)
        \\lw s6,  4 * 24(sp)
        \\lw s7,  4 * 25(sp)
        \\lw s8,  4 * 26(sp)
        \\lw s9,  4 * 27(sp)
        \\lw s10, 4 * 28(sp)
        \\lw s11, 4 * 29(sp)
        \\lw sp,  4 * 30(sp)
        \\sret
    );
}

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

    // Install exception handler
    writeCsr("stvec", @intFromPtr(&kernelEntry));

    common.printf("Hello {s}\n", .{"Kernel!"});

    // Trigger an illegal instruction exception for testing
    asm volatile ("csrrw x0, cycle, x0"); // unimp instruction

    // Should not reach here
    common.printf("This should not be reached!\n", .{});

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
