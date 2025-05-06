const std = @import("std");

const common = @import("common.zig");
const memory = @import("memory.zig");
const process = @import("process.zig");
const trap = @import("trap.zig");
const sbi = @import("sbi.zig");

const PAGE_SIZE = memory.PAGE_SIZE;
const SATP_SV32: u32 = 1 << 31;
const SSTATUS_SPIE: u32 = 1 << 5;
const USER_BASE: u32 = 0x1000000;

extern const __bss: [*]u8;
extern const __bss_end: [*]u8;
extern const __stack_top: [*]u8;
extern const __kernel_base: [*]u8;
extern const __free_ram: [*]u8;
extern const __free_ram_end: [*]u8;

const user_bin = @embedFile("user.bin");

fn writeCsr(comptime reg: []const u8, value: u32) void {
    asm volatile ("csrw " ++ reg ++ ", %[val]"
        :
        : [val] "r" (value),
    );
}

fn userEntry() callconv(.Naked) void {
    asm volatile (
        \\csrw sepc, %[sepc]
        \\csrw sstatus, %[sstatus]
        \\sret
        :
        : [sepc] "r" (USER_BASE),
          [sstatus] "r" (SSTATUS_SPIE),
    );
}

pub fn delay() void {
    for (0..30_000_000) |_| {
        asm volatile ("nop");
    }
}

export fn kernel_main() noreturn {
    const bss_len = @intFromPtr(__bss_end) - @intFromPtr(__bss);
    @memset(__bss[0..bss_len], 0);

    common.printf("\n[rk] booting kernel...\n", .{});

    writeCsr("stvec", @intFromPtr(&kernelEntry));
    memory.next_free_paddr = @intFromPtr(__free_ram);

    process.init();
    _ = process.Process.create(@intFromPtr(&userEntry), user_bin);

    yield();

    common.panic("unexpected return from yield", .{});
}

export fn yield() void {
    if (process.current_proc == null) return;

    var next = process.idle_proc;
    for (0..8) |i| {
        const pid = process.current_proc.?.pid;
        const idx = @mod(pid + i, 8);
        const p = &@field(process, "procs")[idx];

        if (p.state == 1 and p.pid > 0) {
            next = p;
            break;
        }
    }

    if (next == process.current_proc) return;

    const prev = process.current_proc;
    process.current_proc = next;

    asm volatile (
        \\sfence.vma
        \\csrw satp, %[satp]
        \\sfence.vma
        \\csrw sscratch, %[sscratch]
        :
        : [satp] "r" (SATP_SV32 | (@intFromPtr(next.?.page_table) / PAGE_SIZE)),
          [sscratch] "r" (@intFromPtr(&next.?.stack) + next.?.stack.len),
    );

    process.Process.switchContext(&prev.?.sp, &next.?.sp);
}

export fn boot() linksection(".text.boot") callconv(.Naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_main
        :
        : [stack_top] "r" (__stack_top),
    );
}

fn kernelEntry() callconv(.Naked) void {
    asm volatile (
        \\csrw sscratch, sp
        \\addi sp, sp, -4 * 31
        // save registers
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
        // restore registers
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
