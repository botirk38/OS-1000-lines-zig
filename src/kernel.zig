//! Main kernel entry point and core initialization
//! Clean, modular kernel with proper separation of concerns

const std = @import("std");
const arch = @import("arch/riscv32.zig");
const console = @import("hal/console.zig");
const debug = @import("debug/panic.zig");
const allocator = @import("mm/allocator.zig");
const process = @import("proc/process.zig");
const scheduler = @import("proc/scheduler.zig");
const common = @import("common.zig");

const user_bin = @embedFile("user.bin");

extern const __bss: [*]u8;
extern const __bss_end: [*]u8;
extern const __free_ram: [*]u8;
extern const __free_ram_end: [*]u8;

const USER_BASE: u32 = 0x1000000;

/// Main kernel entry point
export fn kernel_main() noreturn {
    // Clear BSS section
    const bss_len = @intFromPtr(__bss_end) - @intFromPtr(__bss);
    @memset(__bss[0..bss_len], 0);

    common.printf("\n[rk] booting kernel...\n", .{});

    common.printf("[rk] setting trap vector...\n", .{});
    // Initialize subsystems
    arch.csr.write("stvec", @intFromPtr(&arch.kernelEntry));

    common.printf("[rk] initializing allocator...\n", .{});
    const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
    const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });
    common.printf("[rk] __free_ram={x}, __free_ram_end={x}\n", .{ @intFromPtr(free_ram), @intFromPtr(free_ram_end) });
    allocator.init(@intFromPtr(free_ram));

    common.printf("[rk] initializing scheduler...\n", .{});
    scheduler.Scheduler.init() catch |err| {
        debug.panic("Failed to initialize scheduler: {}", .{err});
    };

    // Create user process with USER_BASE as entry point (where user binary is loaded)
    _ = process.Process.create(USER_BASE, user_bin) catch |err| {
        debug.panic("Failed to create user process: {}", .{err});
    };

    // Start scheduling
    scheduler.Scheduler.yield();

    debug.panic("unexpected return from yield", .{});
}

/// User entry point setup - transitions from supervisor to user mode
export fn user_entry() callconv(.naked) void {
    asm volatile (
        \\csrw sepc, %[sepc]
        \\csrw sstatus, %[sstatus]
        \\sret
        :
        : [sepc] "r" (USER_BASE),
          [sstatus] "r" (arch.SSTATUS_SPIE),
    );
}

/// Trap handler - called from assembly
export fn handleTrap(frame: *arch.TrapFrame) callconv(.c) void {
    const scause = arch.csr.read("scause");
    const stval = arch.csr.read("stval");
    const sepc = arch.csr.read("sepc");

    debug.panic("trap: scause={x}, stval={x}, sepc={x}, ra={x}, sp={x}", .{ scause, stval, sepc, frame.ra, frame.sp });
}

/// Yield CPU to next process
export fn yield() void {
    scheduler.Scheduler.yield();
}
