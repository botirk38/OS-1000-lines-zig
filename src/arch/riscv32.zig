//! RISC-V 32-bit architecture specific implementations
//! This module contains all RISC-V specific code including assembly routines,
//! CSR operations, and trap handling.

const allocator = @import("allocator");
const log = @import("logger");

// ---------------------------------------------------------------------------
// Private RISC-V implementation details
// ---------------------------------------------------------------------------

const csr = struct {
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

const SATP_SV32: u32 = 1 << 31;
const SSTATUS_SPIE: u32 = 1 << 5;
const SSTATUS_SUM: u32 = 1 << 18;

const sv32 = struct {
    const VPN_BITS: u5 = 10;
    const VPN_MASK: u32 = (1 << VPN_BITS) - 1;
    const VPN1_SHIFT: u5 = 22;
    const VPN0_SHIFT: u5 = 12;
    const PTE_PPN_SHIFT: u5 = 10;
    const PTE_PPN_BITS: u5 = 22;
    const PTE_PPN_MASK: u32 = (1 << PTE_PPN_BITS) - 1;
    const PTE_FLAGS_MASK: u32 = VPN_MASK;
};

const SCAUSE_INTERRUPT_BIT: u32 = 1 << 31;
const SCAUSE_CODE_MASK: u32 = 0x7fff_ffff;

const EXC_ECALL_FROM_U: u32 = 8;
const EXC_ECALL_FROM_S: u32 = 9;
const EXC_INST_PAGE_FAULT: u32 = 12;
const EXC_LOAD_PAGE_FAULT: u32 = 13;
const EXC_STORE_PAGE_FAULT: u32 = 15;

const IRQ_SOFTWARE_S: u32 = 1;
const IRQ_TIMER_S: u32 = 5;
const IRQ_EXTERNAL_S: u32 = 9;

fn isInterrupt(scause: u32) bool {
    return (scause & SCAUSE_INTERRUPT_BIT) != 0;
}

fn causeCode(scause: u32) u32 {
    return scause & SCAUSE_CODE_MASK;
}

fn isException(scause: u32, code: u32) bool {
    return !isInterrupt(scause) and causeCode(scause) == code;
}

// ---------------------------------------------------------------------------
// Public architecture interface
// ---------------------------------------------------------------------------

pub const Word = u32;
pub const VAddr = enum(Word) { _ };
pub const PAddr = enum(Word) { _ };

pub const PagingError = error{
    UnalignedAddress,
    NotMapped,
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

pub const TrapKind = union(enum) {
    exception: Exception,
    interrupt: Interrupt,
};

pub const TrapInfo = struct {
    kind: TrapKind,
    cause: Word,
    value: Word,
    pc: Word,
};

pub const Trap = struct {
    pub const Frame = TrapFrame;

    pub fn initVector() void {
        csr.write("stvec", @intFromPtr(&kernelEntry));
    }

    pub fn read() TrapInfo {
        const scause = csr.read("scause");
        const kind: TrapKind = blk: {
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
    pub fn number(frame: *Trap.Frame) u32 {
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

pub const Context = struct {
    pub fn swap(prev_sp: *Word, next_sp: *Word) void {
        switch_context(prev_sp, next_sp);
    }

    pub fn activateAddressSpace(root: Paging.Root, kernel_stack_top: Word) void {
        const satp = SATP_SV32 | (@intFromPtr(root.ptr) / 4096);
        asm volatile (
            \\sfence.vma
            \\csrw satp, %[satp]
            \\sfence.vma
            \\csrw sscratch, %[sscratch]
            :
            : [satp] "r" (satp),
              [sscratch] "r" (kernel_stack_top),
        );
    }
};

pub const Paging = struct {
    pub const Root = struct {
        ptr: [*]Word,
    };

    pub const Flag = enum {
        read,
        write,
        exec,
        user,
    };

    pub fn rootFromPtr(ptr: [*]Word) Root {
        return .{ .ptr = ptr };
    }

    pub fn map(root: Root, vaddr: VAddr, paddr: PAddr, flags: []const Flag) (PagingError || allocator.AllocError)!void {
        const raw_vaddr = @intFromEnum(vaddr);
        const raw_paddr = @intFromEnum(paddr);

        if (!isAligned(raw_vaddr, allocator.PAGE_SIZE)) return error.UnalignedAddress;
        if (!isAligned(raw_paddr, allocator.PAGE_SIZE)) return error.UnalignedAddress;

        const vpn1 = (raw_vaddr >> sv32.VPN1_SHIFT) & sv32.VPN_MASK;
        var pte1 = PageTableEntry{ .raw = root.ptr[vpn1] };

        if (!pte1.isValid()) {
            const pt_paddr = try allocator.allocPages(1);
            pte1 = PageTableEntry.fromPhysical(pt_paddr, @intFromEnum(PageFlags.valid));
            root.ptr[vpn1] = pte1.raw;
        }

        const vpn0 = (raw_vaddr >> sv32.VPN0_SHIFT) & sv32.VPN_MASK;
        const table0: [*]Word = @ptrFromInt(pte1.getPhysicalAddress());

        var raw_flags: u32 = @intFromEnum(PageFlags.valid);
        for (flags) |f| {
            raw_flags |= switch (f) {
                .read => @intFromEnum(PageFlags.read),
                .write => @intFromEnum(PageFlags.write),
                .exec => @intFromEnum(PageFlags.exec),
                .user => @intFromEnum(PageFlags.user),
            };
        }

        const pte0 = PageTableEntry.fromPhysical(raw_paddr, raw_flags);
        table0[vpn0] = pte0.raw;

        log.debug("mm", "map vaddr={x} -> paddr={x}", .{ raw_vaddr, raw_paddr });
    }

    pub fn unmap(root: Root, vaddr: VAddr) PagingError!void {
        const raw_vaddr = @intFromEnum(vaddr);

        if (!isAligned(raw_vaddr, allocator.PAGE_SIZE)) return error.UnalignedAddress;

        const vpn1 = (raw_vaddr >> sv32.VPN1_SHIFT) & sv32.VPN_MASK;
        const pte1 = PageTableEntry{ .raw = root.ptr[vpn1] };

        if (!pte1.isValid()) return error.NotMapped;

        const vpn0 = (raw_vaddr >> sv32.VPN0_SHIFT) & sv32.VPN_MASK;
        const table0: [*]Word = @ptrFromInt(pte1.getPhysicalAddress());
        table0[vpn0] = 0;
    }
};

// ---------------------------------------------------------------------------
// Private paging helpers
// ---------------------------------------------------------------------------

const PageFlags = enum(u32) {
    valid = 1 << 0,
    read = 1 << 1,
    write = 1 << 2,
    exec = 1 << 3,
    user = 1 << 4,
};

const PageTableEntry = struct {
    raw: u32,

    fn fromPhysical(paddr: u32, flags: u32) PageTableEntry {
        return .{ .raw = ((paddr / 4096) << sv32.PTE_PPN_SHIFT) | (flags & sv32.PTE_FLAGS_MASK) };
    }

    fn isValid(self: PageTableEntry) bool {
        return (self.raw & @intFromEnum(PageFlags.valid)) != 0;
    }

    fn getPhysicalAddress(self: PageTableEntry) u32 {
        return ((self.raw >> sv32.PTE_PPN_SHIFT) & sv32.PTE_PPN_MASK) * 4096;
    }
};

fn isAligned(addr: u32, size: u32) bool {
    return (addr & (size - 1)) == 0;
}

// ---------------------------------------------------------------------------
// Trap frame and assembly
// ---------------------------------------------------------------------------

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

pub extern fn switch_context(prev_sp: *u32, next_sp: *u32) void;

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

extern fn handleTrap(frame: *TrapFrame) callconv(.c) void;
extern fn kernel_main() noreturn;

comptime {
    @import("interface").validate(@This());
}
