//! Main kernel entry point and core initialization
//! Clean, modular kernel with proper separation of concerns

const std = @import("std");
const arch = @import("arch/riscv32.zig");
const console = @import("hal/console.zig");
const debug = @import("debug/panic.zig");
const allocator = @import("mm/allocator.zig");
const process = @import("proc/process.zig");
const common = @import("common.zig");

const user_bin = @embedFile("user.bin");

extern const __bss: [*]u8;
extern const __bss_end: [*]u8;
extern const __free_ram: [*]u8;

const USER_BASE: u32 = 0x1000000;

/// Main kernel entry point
export fn kernel_main() noreturn {
    // Clear BSS section
    const bss_len = @intFromPtr(__bss_end) - @intFromPtr(__bss);
    @memset(__bss[0..bss_len], 0);

    common.printf("\n[rk] booting kernel...\n", .{});

    // Initialize subsystems
    arch.csr.write("stvec", @intFromPtr(&arch.kernelEntry));
    allocator.init(@intFromPtr(__free_ram));

    process.Scheduler.init() catch |err| {
        debug.panic("Failed to initialize scheduler: {}", .{err});
    };

    // Create user process
    _ = process.Process.create(@intFromPtr(&userEntry), user_bin) catch |err| {
        debug.panic("Failed to create user process: {}", .{err});
    };

    // Start scheduling
    process.Scheduler.yield();

    debug.panic("unexpected return from yield", .{});
}

/// User entry point setup
fn userEntry() callconv(.naked) void {
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

    debug.panic("trap: scause={x}, stval={x}, sepc={x}, ra={x}, sp={x}",
        .{ scause, stval, sepc, frame.ra, frame.sp });
}

/// Yield CPU to next process
export fn yield() void {
    process.Scheduler.yield();
}

/// Delay function for testing
pub fn delay() void {
    for (0..30_000_000) |_| {
        asm volatile ("nop");
    }
}