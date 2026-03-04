//! Trap and interrupt handling for the kernel.
//! Exports: handleTrap (called from kernelEntry asm), user_entry.

const arch = @import("arch");
const panic_lib = @import("panic");
const syscall = @import("syscall");
const log = @import("logger");

/// Called from user_entry global asm to log before sret.
export fn user_entry_log() callconv(.c) void {
    const sepc = arch.csr.read("sepc");
    const sstatus = arch.csr.read("sstatus");
    log.debug("trap", "user_entry: about to sret sepc={x} sstatus={x}", .{ sepc, sstatus });
}

// Global assembly for user_entry — no compiler interference with callconv(.naked).
// USER_BASE = 0x1000000, SSTATUS_SPIE|SSTATUS_SUM = 0x40020.
comptime {
    asm (
        \\.global user_entry
        \\.type user_entry, @function
        \\user_entry:
        \\  li t0, 0x1000000
        \\  csrw sepc, t0
        \\  li t0, 0x40020
        \\  csrw sstatus, t0
        \\  call user_entry_log
        \\  sret
    );
}

/// Extern declaration so process.zig can take the address of user_entry.
pub extern fn user_entry() void;

/// Trap handler called from `kernelEntry` assembly stub.
export fn handleTrap(frame: *arch.TrapFrame) callconv(.c) void {
    const scause = arch.csr.read("scause");
    const stval = arch.csr.read("stval");
    const sepc = arch.csr.read("sepc");

    log.debug("trap", "handleTrap scause={x} sepc={x} stval={x}", .{ scause, sepc, stval });

    if (arch.isException(scause, arch.ECALL_FROM_U)) {
        syscall.dispatch(frame);
        arch.csr.write("sepc", sepc + 4);
        return;
    }

    panic_lib.panic("trap: scause={x}, stval={x}, sepc={x}, ra={x}, sp={x}", .{
        scause,
        stval,
        sepc,
        frame.ra,
        frame.sp,
    });
}
