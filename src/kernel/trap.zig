//! Trap and interrupt handling for the kernel.
//! Exports: handleTrap (called from kernelEntry asm), user_entry.

const arch = @import("arch");
const panic_lib = @import("panic");
const layout = @import("layout");
const syscall = @import("syscall");

/// Naked trampoline that switches to supervisor mode and jumps to USER_BASE.
/// Called as the `ra` of a freshly-created user process context frame.
export fn user_entry() callconv(.naked) void {
    asm volatile (
        \\csrw sepc, %[sepc]
        \\csrw sstatus, %[sstatus]
        \\sret
        :
        : [sepc] "r" (layout.USER_BASE),
          [sstatus] "r" (arch.SSTATUS_SPIE | arch.SSTATUS_SUM),
    );
}

/// Trap handler called from `kernelEntry` assembly stub.
export fn handleTrap(frame: *arch.TrapFrame) callconv(.c) void {
    const scause = arch.csr.read("scause");
    const stval = arch.csr.read("stval");
    const sepc = arch.csr.read("sepc");

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
