//! Architecture interface contract.
//!
//! Every architecture implementation must export the same named types and
//! structs so that generic kernel code can depend on them without knowing
//! the underlying ISA. This module provides a small comptime validator that
//! gives early, clear errors when an arch is incomplete.
//!
//! Usage in an arch implementation:
//!   comptime {
//!       @import("interface").validate(@This());
//!   }

/// Validates that `Arch` exports the required interface.
/// Call this at the bottom of every arch implementation module.
pub fn validate(comptime Arch: type) void {
    comptime {
        if (!@hasDecl(Arch, "Word")) @compileError("arch missing 'Word'");
        if (!@hasDecl(Arch, "VAddr")) @compileError("arch missing 'VAddr'");
        if (!@hasDecl(Arch, "PAddr")) @compileError("arch missing 'PAddr'");

        if (!@hasDecl(Arch, "TrapKind")) @compileError("arch missing 'TrapKind'");
        if (!@hasDecl(Arch, "TrapInfo")) @compileError("arch missing 'TrapInfo'");
        if (!@hasDecl(Arch, "Trap")) @compileError("arch missing 'Trap'");

        if (!@hasDecl(Arch.Trap, "Frame")) @compileError("arch.Trap missing 'Frame'");
        if (!@hasDecl(Arch.Trap, "initVector")) @compileError("arch.Trap missing 'initVector'");
        if (!@hasDecl(Arch.Trap, "read")) @compileError("arch.Trap missing 'read'");
        if (!@hasDecl(Arch, "Exception")) @compileError("arch missing 'Exception'");
        if (!@hasDecl(Arch, "Interrupt")) @compileError("arch missing 'Interrupt'");
        if (!@hasDecl(Arch.Trap, "setPc")) @compileError("arch.Trap missing 'setPc'");

        if (!@hasDecl(Arch, "Syscall")) @compileError("arch missing 'Syscall'");
        if (!@hasDecl(Arch.Syscall, "number")) @compileError("arch.Syscall missing 'number'");
        if (!@hasDecl(Arch.Syscall, "arg")) @compileError("arch.Syscall missing 'arg'");
        if (!@hasDecl(Arch.Syscall, "setReturn")) @compileError("arch.Syscall missing 'setReturn'");

        if (!@hasDecl(Arch, "PagingError")) @compileError("arch missing 'PagingError'");
        if (!@hasDecl(Arch, "Paging")) @compileError("arch missing 'Paging'");
        if (!@hasDecl(Arch.Paging, "Root")) @compileError("arch.Paging missing 'Root'");
        if (!@hasDecl(Arch.Paging, "Flag")) @compileError("arch.Paging missing 'Flag'");
        if (!@hasDecl(Arch.Paging, "rootFromPtr")) @compileError("arch.Paging missing 'rootFromPtr'");
        if (!@hasDecl(Arch.Paging, "map")) @compileError("arch.Paging missing 'map'");
        if (!@hasDecl(Arch.Paging, "unmap")) @compileError("arch.Paging missing 'unmap'");

        if (!@hasDecl(Arch, "Context")) @compileError("arch missing 'Context'");
        if (!@hasDecl(Arch.Context, "swap")) @compileError("arch.Context missing 'swap'");
        if (!@hasDecl(Arch.Context, "activateAddressSpace")) @compileError("arch.Context missing 'activateAddressSpace'");
    }
}
