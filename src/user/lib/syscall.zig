const numbers = @import("syscall");

fn syscallNumber(comptime n: numbers.SysCall) u32 {
    return @intFromEnum(n);
}

fn syscall(num: u32, arg0: u32, arg1: u32, arg2: u32) i32 {
    var ret: i32 = undefined;
    asm volatile ("ecall"
        : [ret] "={a0}" (ret),
        : [num] "{a7}" (num),
          [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
        : .{ .memory = true });
    return ret;
}

pub fn write(fd: u32, buf: [*]const u8, len: u32) i32 {
    return syscall(syscallNumber(.write), fd, @intFromPtr(buf), len);
}

pub fn read(fd: u32, buf: [*]u8, len: u32) i32 {
    return syscall(syscallNumber(.read), fd, @intFromPtr(buf), len);
}

pub fn exit(code: i32) noreturn {
    _ = syscall(syscallNumber(.exit), @bitCast(code), 0, 0);
    unreachable;
}

pub fn yield() void {
    _ = syscall(syscallNumber(.yield), 0, 0, 0);
}
