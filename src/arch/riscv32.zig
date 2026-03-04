//! RISC-V 32-bit architecture specific implementations
//! This module contains all RISC-V specific code including assembly routines,
//! CSR operations, and trap handling.

/// RISC-V Control and Status Register operations
pub const csr = struct {
    pub fn read(comptime reg: []const u8) u32 {
        return asm volatile ("csrr %[ret], " ++ reg
            : [ret] "=r" (-> u32),
        );
    }

    pub fn write(comptime reg: []const u8, value: u32) void {
        asm volatile ("csrw " ++ reg ++ ", %[val]"
            :
            : [val] "r" (value),
        );
    }
};

/// RISC-V specific constants
pub const SATP_SV32: u32 = 1 << 31;
pub const SSTATUS_SPIE: u32 = 1 << 5;
pub const SSTATUS_SUM: u32 = 1 << 18; // Supervisor User Memory access
pub const ECALL_FROM_U: u32 = 8;
pub const ECALL_FROM_S: u32 = 9;

/// SV32 two-level page-table constants (RISC-V Privileged spec §4.3).
pub const sv32 = struct {
    /// Each VPN field is 10 bits wide.
    pub const VPN_BITS: u5 = 10;
    /// Mask for a single 10-bit VPN (or the 10-bit PTE flags field).
    pub const VPN_MASK: u32 = (1 << VPN_BITS) - 1; // 0x3FF
    /// VPN[1]: bits [31:22] of a virtual address.
    pub const VPN1_SHIFT: u5 = 22;
    /// VPN[0]: bits [21:12] of a virtual address.
    pub const VPN0_SHIFT: u5 = 12;
    /// PPN starts at bit 10 inside a page-table entry.
    pub const PTE_PPN_SHIFT: u5 = 10;
    /// The PPN field of a PTE is 22 bits wide (SV32 has a 34-bit physical space).
    pub const PTE_PPN_BITS: u5 = 22;
    /// Mask for the full 22-bit PPN stored in a PTE.
    pub const PTE_PPN_MASK: u32 = (1 << PTE_PPN_BITS) - 1; // 0x3FFFFF
    /// Mask for the 10-bit flags/RSW field at the bottom of a PTE.
    pub const PTE_FLAGS_MASK: u32 = VPN_MASK; // 0x3FF
};

pub const SCAUSE_INTERRUPT_BIT: u32 = 1 << 31;
pub const SCAUSE_CODE_MASK: u32 = 0x7fff_ffff;
// Exception codes (when interrupt bit is 0)
pub const EXC_INST_ADDR_MISALIGNED: u32 = 0;
pub const EXC_INST_ACCESS_FAULT: u32 = 1;
pub const EXC_ILLEGAL_INSTRUCTION: u32 = 2;
pub const EXC_BREAKPOINT: u32 = 3;
pub const EXC_LOAD_ADDR_MISALIGNED: u32 = 4;
pub const EXC_LOAD_ACCESS_FAULT: u32 = 5;
pub const EXC_STORE_ADDR_MISALIGNED: u32 = 6;
pub const EXC_STORE_ACCESS_FAULT: u32 = 7;
pub const EXC_ECALL_FROM_U: u32 = 8;
pub const EXC_ECALL_FROM_S: u32 = 9;
pub const EXC_INST_PAGE_FAULT: u32 = 12;
pub const EXC_LOAD_PAGE_FAULT: u32 = 13;
pub const EXC_STORE_PAGE_FAULT: u32 = 15;
// Interrupt codes (when interrupt bit is 1)
pub const IRQ_SOFTWARE_S: u32 = 1;
pub const IRQ_TIMER_S: u32 = 5;
pub const IRQ_EXTERNAL_S: u32 = 9;

pub fn isInterrupt(scause: u32) bool {
    return (scause & SCAUSE_INTERRUPT_BIT) != 0;
}
pub fn causeCode(scause: u32) u32 {
    return scause & SCAUSE_CODE_MASK;
}
pub fn isException(scause: u32, code: u32) bool {
    return !isInterrupt(scause) and causeCode(scause) == code;
}
pub fn isInterruptCode(scause: u32, code: u32) bool {
    return isInterrupt(scause) and causeCode(scause) == code;
}

/// Trap frame structure for RISC-V register context
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

// switch_context(prev_sp: *u32, next_sp: *u32) — global assembly, no compiler interference.
// a0 = prev_sp, a1 = next_sp, exactly as the C reference.
comptime {
    asm (
        \\.global switch_context
        \\.type switch_context, @function
        \\switch_context:
        \\  addi sp, sp, -13 * 4
        \\  sw ra,  0  * 4(sp)
        \\  sw s0,  1  * 4(sp)
        \\  sw s1,  2  * 4(sp)
        \\  sw s2,  3  * 4(sp)
        \\  sw s3,  4  * 4(sp)
        \\  sw s4,  5  * 4(sp)
        \\  sw s5,  6  * 4(sp)
        \\  sw s6,  7  * 4(sp)
        \\  sw s7,  8  * 4(sp)
        \\  sw s8,  9  * 4(sp)
        \\  sw s9,  10 * 4(sp)
        \\  sw s10, 11 * 4(sp)
        \\  sw s11, 12 * 4(sp)
        \\  sw sp, (a0)
        \\  lw sp, (a1)
        \\  lw ra,  0  * 4(sp)
        \\  lw s0,  1  * 4(sp)
        \\  lw s1,  2  * 4(sp)
        \\  lw s2,  3  * 4(sp)
        \\  lw s3,  4  * 4(sp)
        \\  lw s4,  5  * 4(sp)
        \\  lw s5,  6  * 4(sp)
        \\  lw s6,  7  * 4(sp)
        \\  lw s7,  8  * 4(sp)
        \\  lw s8,  9  * 4(sp)
        \\  lw s9,  10 * 4(sp)
        \\  lw s10, 11 * 4(sp)
        \\  lw s11, 12 * 4(sp)
        \\  addi sp, sp, 13 * 4
        \\  ret
    );
}

/// Extern declaration so Zig code can call switch_context by address.
pub extern fn switch_context(prev_sp: *u32, next_sp: *u32) void;

/// Kernel entry point for trap handling.
/// On entry sp holds the interrupted context's sp (user or kernel).
/// sscratch holds the top of the current process's kernel stack.
/// csrrw atomically swaps them: sp gets the kernel stack, sscratch gets the
/// interrupted sp. After saving all registers, sscratch is restored to the
/// kernel stack top so the next trap finds it ready again.
pub fn kernelEntry() callconv(.naked) void {
    asm volatile (
    // Swap sp and sscratch: sp <- kernel stack top, sscratch <- user sp
        \\csrrw sp, sscratch, sp
        \\addi sp, sp, -4 * 31
        // Save all general-purpose registers except sp (saved at slot 30)
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
        // sscratch now holds the interrupted sp; save it at slot 30
        \\csrr a0, sscratch
        \\sw a0,  4 * 30(sp)
        // Restore sscratch to kernel stack top for the next trap
        \\addi a0, sp, 4 * 31
        \\csrw sscratch, a0
        // Call handleTrap(frame)
        \\mv a0, sp
        \\call handleTrap
        // Restore all registers
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

/// Boot entry point
export fn boot() linksection(".text.boot") callconv(.naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_main
        :
        : [stack_top] "r" (@extern([*]u8, .{ .name = "__stack_top" })),
    );
}

extern fn handleTrap(frame: *TrapFrame) callconv(.c) void;
extern fn kernel_main() noreturn;
