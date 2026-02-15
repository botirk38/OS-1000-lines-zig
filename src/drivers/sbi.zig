const std = @import("std");

pub const SbiCall = struct {
    a0: u32 = 0,
    a1: u32 = 0,
    a2: u32 = 0,
    a3: u32 = 0,
    a4: u32 = 0,
    a5: u32 = 0,
    fid: u32,
    eid: u32,
};

pub const SbiRet = struct {
    err: u32,
    value: u32,
};

pub fn call(args: SbiCall) SbiRet {
    var err: u32 = undefined;
    var val: u32 = undefined;
    asm volatile ("ecall"
        : [err] "={a0}" (err),
          [val] "={a1}" (val),
        : [arg0] "{a0}" (args.a0),
          [arg1] "{a1}" (args.a1),
          [arg2] "{a2}" (args.a2),
          [arg3] "{a3}" (args.a3),
          [arg4] "{a4}" (args.a4),
          [arg5] "{a5}" (args.a5),
          [fid] "{a6}" (args.fid),
          [eid] "{a7}" (args.eid),
        : .{ .memory = true });
    return .{ .err = err, .value = val };
}

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

pub fn putChar(c: u8) void {
    _ = call(.{ .a0 = c, .fid = 0, .eid = 1 });
}

pub fn shutdown() noreturn {
    _ = call(.{ .fid = 0, .eid = 8 });
    unreachable;
}
