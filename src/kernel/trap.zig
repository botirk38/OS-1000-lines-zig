//! Trap and interrupt handling for the kernel.
//! Exports: handleTrap (called from kernelEntry asm), user_entry.

const arch = @import("arch");
const context = @import("kernel_context");
const log = @import("logger");

/// Called from user_entry global asm to log before sret.
export fn user_entry_log() callconv(.c) void {
    const info = arch.Trap.read();
    log.debug("trap", "user_entry: about to sret sepc={x}", .{info.pc});
}

// Global assembly for user_entry — no compiler interference with callconv(.naked).
comptime {
    asm (
        \\.global user_entry
        \\.type user_entry, @function
        \\user_entry:
        // sepc = USER_BASE (layout.USER_BASE = 0x1000000)
        \\  li t0, 0x1000000
        \\  csrw sepc, t0
        // sstatus = SSTATUS_SPIE | SSTATUS_SUM (0x20 | 0x40000 = 0x40020)
        \\  li t0, 0x40020
        \\  csrw sstatus, t0
        \\  call user_entry_log
        \\  sret
    );
}

/// Extern declaration so process.zig can take the address of user_entry.
pub extern fn user_entry() void;

/// Trap handler called from `kernelEntry` assembly stub.
export fn handleTrap(frame: *arch.Trap.Frame) callconv(.c) void {
    context.Context.current().handleTrap(frame);
}
