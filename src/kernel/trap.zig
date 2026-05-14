//! Trap and interrupt handling for the kernel.
//! Exports: handleTrap (called from kernelEntry asm), user_entry.

const arch = @import("arch");
const context = @import("kernel_context");
const syscall = @import("kernel_syscall");
const log = @import("logger");
const panic_lib = @import("panic");

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
    const ctx = context.Context.current();
    const trap = arch.Trap.read();

    log.debug("trap", "handleTrap kind={s} cause={x} pc={x} stval={x}", .{
        switch (trap.kind) {
            .exception => |e| @tagName(e),
            .interrupt => |i| @tagName(i),
        },
        trap.cause,
        trap.pc,
        trap.value,
    });

    switch (trap.kind) {
        .exception => |exception| switch (exception) {
            .user_syscall => {
                syscall.dispatch(ctx, frame);
                arch.Trap.setPc(trap.pc + 4);
                return;
            },
            else => {},
        },
        .interrupt => |interrupt| switch (interrupt) {
            else => {},
        },
    }

    panic_lib.panic("trap: cause={x}, stval={x}, sepc={x}, ra={x}, sp={x}", .{
        trap.cause,
        trap.value,
        trap.pc,
        frame.ra,
        frame.sp,
    });
}
