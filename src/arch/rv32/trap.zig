const csr = @import("csr.zig");
const Word = @import("arch.zig").Word;

const SCAUSE_INTERRUPT_BIT: Word = 1 << 31;
const SCAUSE_CODE_MASK: Word = 0x7fff_ffff;

const EXC_ECALL_FROM_U: Word = 8;
const EXC_ECALL_FROM_S: Word = 9;
const EXC_INST_PAGE_FAULT: Word = 12;
const EXC_LOAD_PAGE_FAULT: Word = 13;
const EXC_STORE_PAGE_FAULT: Word = 15;

const IRQ_SOFTWARE_S: Word = 1;
const IRQ_TIMER_S: Word = 5;
const IRQ_EXTERNAL_S: Word = 9;

fn isInterrupt(scause: Word) bool {
    return (scause & SCAUSE_INTERRUPT_BIT) != 0;
}

fn causeCode(scause: Word) Word {
    return scause & SCAUSE_CODE_MASK;
}

fn isException(scause: Word, code: Word) bool {
    return !isInterrupt(scause) and causeCode(scause) == code;
}

pub const Trap = struct {
    pub const Frame = packed struct {
        ra: Word,
        gp: Word,
        tp: Word,
        t0: Word,
        t1: Word,
        t2: Word,
        t3: Word,
        t4: Word,
        t5: Word,
        t6: Word,
        a0: Word,
        a1: Word,
        a2: Word,
        a3: Word,
        a4: Word,
        a5: Word,
        a6: Word,
        a7: Word,
        s0: Word,
        s1: Word,
        s2: Word,
        s3: Word,
        s4: Word,
        s5: Word,
        s6: Word,
        s7: Word,
        s8: Word,
        s9: Word,
        s10: Word,
        s11: Word,
        sp: Word,
    };

    pub const Exception = enum {
        user_syscall,
        supervisor_syscall,
        breakpoint,
        illegal_instruction,
        instruction_page_fault,
        load_page_fault,
        store_page_fault,
        unknown,
    };

    pub const Interrupt = enum {
        software,
        timer,
        external,
        unknown,
    };

    pub const Kind = union(enum) {
        exception: Exception,
        interrupt: Interrupt,
    };

    pub const Info = struct {
        kind: Kind,
        cause: Word,
        value: Word,
        pc: Word,
    };

    pub fn initVector() void {
        csr.write("stvec", @intFromPtr(&kernelEntry));
    }

    pub fn read() Info {
        const scause = csr.read("scause");
        const kind: Kind = blk: {
            if (isException(scause, EXC_ECALL_FROM_U)) break :blk .{ .exception = .user_syscall };
            if (isException(scause, EXC_ECALL_FROM_S)) break :blk .{ .exception = .supervisor_syscall };
            if (isException(scause, 3)) break :blk .{ .exception = .breakpoint };
            if (isException(scause, 2)) break :blk .{ .exception = .illegal_instruction };
            if (isException(scause, EXC_INST_PAGE_FAULT)) break :blk .{ .exception = .instruction_page_fault };
            if (isException(scause, EXC_LOAD_PAGE_FAULT)) break :blk .{ .exception = .load_page_fault };
            if (isException(scause, EXC_STORE_PAGE_FAULT)) break :blk .{ .exception = .store_page_fault };
            if (isInterrupt(scause)) {
                const code = causeCode(scause);
                if (code == IRQ_EXTERNAL_S) break :blk .{ .interrupt = .external };
                if (code == IRQ_TIMER_S) break :blk .{ .interrupt = .timer };
                if (code == IRQ_SOFTWARE_S) break :blk .{ .interrupt = .software };
                break :blk .{ .interrupt = .unknown };
            }
            break :blk .{ .exception = .unknown };
        };
        return .{
            .kind = kind,
            .cause = scause,
            .value = csr.read("stval"),
            .pc = csr.read("sepc"),
        };
    }

    pub fn setPc(new_pc: Word) void {
        csr.write("sepc", new_pc);
    }
};

pub const Syscall = struct {
    pub fn number(frame: *Trap.Frame) Word {
        return frame.a7;
    }

    pub fn arg(frame: *Trap.Frame, index: u3) Word {
        return switch (index) {
            0 => frame.a0,
            1 => frame.a1,
            2 => frame.a2,
            else => unreachable,
        };
    }

    pub fn setReturn(frame: *Trap.Frame, value: Word) void {
        frame.a0 = value;
    }
};

pub fn kernelEntry() callconv(.naked) void {
    asm volatile (
        \\csrrw sp, sscratch, sp
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
        \\sw a0,  4 * 30(sp)
        \\addi a0, sp, 4 * 31
        \\csrw sscratch, a0
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

export fn boot() linksection(".text.boot") callconv(.naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_main
        :
        : [stack_top] "r" (@extern([*]u8, .{ .name = "__stack_top" })),
    );
}

extern fn handleTrap(frame: *Trap.Frame) callconv(.c) void;
extern fn kernel_main() noreturn;
