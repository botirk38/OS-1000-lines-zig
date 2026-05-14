const arch = @import("arch");
const context = @import("kernel_context");
const abi = @import("abi");
const fs = @import("fs");
const sbi = @import("sbi");
const log = @import("logger");

pub fn dispatch(ctx: *context.Context, frame: *arch.Trap.Frame) void {
    const syscall_enum: abi.Syscall = @enumFromInt(arch.Syscall.number(frame));

    log.debug("syscall", "syscall={s} a0={x} a1={x} a2={x}", .{
        @tagName(syscall_enum),
        arch.Syscall.arg(frame, 0),
        arch.Syscall.arg(frame, 1),
        arch.Syscall.arg(frame, 2),
    });

    switch (syscall_enum) {
        .write => {
            arch.Syscall.setReturn(frame, @bitCast(syscallWrite(frame)));
        },
        .read => {
            arch.Syscall.setReturn(frame, @bitCast(syscallRead(ctx, frame)));
        },
        .exit => {
            syscallExit(ctx, @bitCast(arch.Syscall.arg(frame, 0)));
        },
        .yield => {
            ctx.yield();
        },
        .getpid => {
            arch.Syscall.setReturn(frame, syscallGetpid(ctx));
        },
        .readfile => {
            arch.Syscall.setReturn(frame, @bitCast(syscallReadFile(frame)));
        },
        .writefile => {
            arch.Syscall.setReturn(frame, @bitCast(syscallWriteFile(frame)));
        },
        else => {
            arch.Syscall.setReturn(frame, @bitCast(@as(i32, -1)));
        },
    }
}

fn syscallWrite(frame: *arch.Trap.Frame) i32 {
    const fd = arch.Syscall.arg(frame, 0);
    const buf = arch.Syscall.arg(frame, 1);
    const len = arch.Syscall.arg(frame, 2);

    if (fd != 1 and fd != 2) return -1;

    const ptr: [*]const u8 = @ptrFromInt(buf);
    var i: u32 = 0;
    while (i < len) : (i += 1) {
        sbi.putChar(ptr[i]);
    }
    return @intCast(i);
}

fn syscallRead(ctx: *context.Context, frame: *arch.Trap.Frame) i32 {
    const fd = arch.Syscall.arg(frame, 0);
    const buf = arch.Syscall.arg(frame, 1);
    const len = arch.Syscall.arg(frame, 2);

    if (fd != 0) return -1;
    if (len == 0) return 0;

    const ptr: [*]u8 = @ptrFromInt(buf);
    const ch = while (true) {
        const c = sbi.getChar();
        if (c >= 0) break c;
        ctx.yield();
    };

    ptr[0] = @intCast(ch);
    return 1;
}

fn syscallExit(ctx: *context.Context, code: i32) noreturn {
    if (ctx.currentProcess()) |p| {
        p.markExited();
        log.info("proc", "process {} exited with code {}", .{ p.pid, code });
    }
    while (true) {
        ctx.yield();
    }
}

fn syscallGetpid(ctx: *context.Context) u32 {
    if (ctx.currentProcess()) |p| return @intCast(p.pid);
    return 0;
}

fn syscallReadFile(frame: *arch.Trap.Frame) i32 {
    const filename: [*:0]const u8 = @ptrFromInt(arch.Syscall.arg(frame, 0));
    const buf: [*]u8 = @ptrFromInt(arch.Syscall.arg(frame, 1));
    const len: usize = @truncate(arch.Syscall.arg(frame, 2));

    const file = fs.lookup(filename) orelse return -1;
    const copy_len = @min(len, file.size);
    @memcpy(buf[0..copy_len], file.data[0..copy_len]);
    return @intCast(copy_len);
}

fn syscallWriteFile(frame: *arch.Trap.Frame) i32 {
    const filename: [*:0]const u8 = @ptrFromInt(arch.Syscall.arg(frame, 0));
    const buf: [*]const u8 = @ptrFromInt(arch.Syscall.arg(frame, 1));
    const len: usize = @truncate(arch.Syscall.arg(frame, 2));

    const file = fs.lookup(filename) orelse fs.create(filename);
    const f = file orelse return -1;

    const copy_len = @min(len, f.data.len);
    @memcpy(f.data[0..copy_len], buf[0..copy_len]);
    f.size = copy_len;

    fs.flush();

    return @intCast(copy_len);
}
