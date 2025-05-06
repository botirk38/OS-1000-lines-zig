const common = @import("common.zig");

pub const TrapFrame = packed struct {
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

fn readCsr(comptime reg: []const u8) u32 {
    return asm volatile ("csrr %[ret], " ++ reg
        : [ret] "=r" (-> u32),
    );
}

export fn handleTrap(frame: *TrapFrame) callconv(.C) void {
    const scause = readCsr("scause");
    const stval = readCsr("stval");
    const sepc = readCsr("sepc");
    common.panic("trap: scause={x}, stval={x}, sepc={x}, ra={x}, sp={x}", .{ scause, stval, sepc, frame.ra, frame.sp });
}
