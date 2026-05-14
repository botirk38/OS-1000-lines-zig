const arch = @import("arch");
const log = @import("logger");
const io = @import("io.zig");
const proc = @import("proc.zig");
const fs = @import("fs");

pub const SysCall = enum(u32) {
    write = 1,
    read = 2,
    exit = 3,
    yield = 4,
    getpid = 5,
    readfile = 6,
    writefile = 7,
    _,
};

pub fn dispatch(frame: *arch.Trap.Frame) void {
    const syscall_enum: SysCall = @enumFromInt(arch.Syscall.number(frame));

    log.debug("syscall", "syscall={} a0={x} a1={x} a2={x}", .{
        arch.Syscall.number(frame),
        arch.Syscall.arg(frame, 0),
        arch.Syscall.arg(frame, 1),
        arch.Syscall.arg(frame, 2),
    });

    switch (syscall_enum) {
        .write => {
            arch.Syscall.setReturn(frame, @bitCast(io.write(
                arch.Syscall.arg(frame, 0),
                arch.Syscall.arg(frame, 1),
                arch.Syscall.arg(frame, 2),
            )));
        },
        .read => {
            arch.Syscall.setReturn(frame, @bitCast(io.read(
                arch.Syscall.arg(frame, 0),
                arch.Syscall.arg(frame, 1),
                arch.Syscall.arg(frame, 2),
            )));
        },
        .exit => {
            proc.exit(@bitCast(arch.Syscall.arg(frame, 0)));
        },
        .yield => {
            proc.yield();
        },
        .getpid => {
            arch.Syscall.setReturn(frame, proc.getpid());
        },
        .readfile => {
            const filename: [*:0]const u8 = @ptrFromInt(arch.Syscall.arg(frame, 0));
            const buf: [*]u8 = @ptrFromInt(arch.Syscall.arg(frame, 1));
            const len: usize = @truncate(arch.Syscall.arg(frame, 2));

            const file = fs.lookup(filename) orelse {
                arch.Syscall.setReturn(frame, @bitCast(@as(i32, -1)));
                return;
            };

            const copy_len = @min(len, file.size);
            @memcpy(buf[0..copy_len], file.data[0..copy_len]);
            arch.Syscall.setReturn(frame, @bitCast(@as(i32, @intCast(copy_len))));
        },
        .writefile => {
            const filename: [*:0]const u8 = @ptrFromInt(arch.Syscall.arg(frame, 0));
            const buf: [*]const u8 = @ptrFromInt(arch.Syscall.arg(frame, 1));
            const len: usize = @truncate(arch.Syscall.arg(frame, 2));

            const file = fs.lookup(filename) orelse fs.create(filename);
            const f = file orelse {
                arch.Syscall.setReturn(frame, @bitCast(@as(i32, -1)));
                return;
            };

            const copy_len = @min(len, f.data.len);
            @memcpy(f.data[0..copy_len], buf[0..copy_len]);
            f.size = copy_len;

            fs.flush();

            arch.Syscall.setReturn(frame, @bitCast(@as(i32, @intCast(copy_len))));
        },
        else => {
            arch.Syscall.setReturn(frame, @bitCast(@as(i32, -1)));
        },
    }
}
