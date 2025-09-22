//! RISC-V Supervisor Binary Interface (SBI) implementation
//! Provides standardized interface to firmware/hypervisor services

const std = @import("std");

/// SBI call arguments structure
pub const SbiArgs = struct {
    a0: u32 = 0,
    a1: u32 = 0,
    a2: u32 = 0,
    a3: u32 = 0,
    a4: u32 = 0,
    a5: u32 = 0,
    fid: u32,
    eid: u32,
};

/// SBI call result
pub const SbiResult = struct {
    err: i32,
    value: i32,
};

/// Make an SBI call with the given arguments
pub fn call(args: SbiArgs) SbiResult {
    var err: i32 = undefined;
    var value: i32 = undefined;

    asm volatile (
        \\mv a0, %[a0]
        \\mv a1, %[a1]
        \\mv a2, %[a2]
        \\mv a3, %[a3]
        \\mv a4, %[a4]
        \\mv a5, %[a5]
        \\mv a6, %[fid]
        \\mv a7, %[eid]
        \\ecall
        \\mv %[err], a0
        \\mv %[value], a1
        : [err] "=r" (err),
          [value] "=r" (value),
        : [a0] "r" (args.a0),
          [a1] "r" (args.a1),
          [a2] "r" (args.a2),
          [a3] "r" (args.a3),
          [a4] "r" (args.a4),
          [a5] "r" (args.a5),
          [fid] "r" (args.fid),
          [eid] "r" (args.eid),
        : .{ .memory = true }
    );
    return .{ .err = err, .value = value };
}

/// SBI Extension IDs
pub const Extension = enum(u32) {
    legacy_set_timer = 0x00,
    legacy_console_putchar = 0x01,
    legacy_console_getchar = 0x02,
    legacy_clear_ipi = 0x03,
    legacy_send_ipi = 0x04,
    legacy_remote_fence_i = 0x05,
    legacy_remote_sfence_vma = 0x06,
    legacy_remote_sfence_vma_asid = 0x07,
    legacy_shutdown = 0x08,
    base = 0x10,
    timer = 0x54494D45,
    ipi = 0x735049,
    rfence = 0x52464E43,
    hsm = 0x48534D,
    srst = 0x53525354,
};

/// Put a character using SBI legacy console
pub fn putChar(c: u8) void {
    _ = call(.{
        .a0 = c,
        .fid = 0,
        .eid = @intFromEnum(Extension.legacy_console_putchar),
    });
}

/// Shutdown the system using SBI
pub fn shutdown() noreturn {
    _ = call(.{
        .fid = 0,
        .eid = @intFromEnum(Extension.legacy_shutdown),
    });
    unreachable;
}