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

pub fn dispatch(frame: *arch.TrapFrame) void {
    const syscall_enum: SysCall = @enumFromInt(frame.a7);

    log.debug("syscall", "syscall={} a0={x} a1={x} a2={x}", .{ frame.a7, frame.a0, frame.a1, frame.a2 });

    switch (syscall_enum) {
        .write => {
            frame.a0 = @bitCast(io.write(frame.a0, frame.a1, frame.a2));
        },
        .read => {
            frame.a0 = @bitCast(io.read(frame.a0, frame.a1, frame.a2));
        },
        .exit => {
            proc.exit(@bitCast(frame.a0));
        },
        .yield => {
            proc.yield();
        },
        .getpid => {
            frame.a0 = proc.getpid();
        },
        .readfile => {
            const filename: [*:0]const u8 = @ptrFromInt(frame.a0);
            const buf: [*]u8 = @ptrFromInt(frame.a1);
            const len: usize = @truncate(frame.a2);

            const file = fs.lookup(filename) orelse {
                frame.a0 = @bitCast(@as(i32, -1));
                return;
            };

            const copy_len = @min(len, file.size);
            @memcpy(buf[0..copy_len], file.data[0..copy_len]);
            frame.a0 = @bitCast(@as(i32, @intCast(copy_len)));
        },
        .writefile => {
            const filename: [*:0]const u8 = @ptrFromInt(frame.a0);
            const buf: [*]const u8 = @ptrFromInt(frame.a1);
            const len: usize = @truncate(frame.a2);

            const file = fs.lookup(filename) orelse fs.create(filename);
            const f = file orelse {
                frame.a0 = @bitCast(@as(i32, -1));
                return;
            };

            const copy_len = @min(len, f.data.len);
            @memcpy(f.data[0..copy_len], buf[0..copy_len]);
            f.size = copy_len;

            fs.flush();

            frame.a0 = @bitCast(@as(i32, @intCast(copy_len)));
        },
        else => {
            frame.a0 = @bitCast(@as(i32, -1));
        },
    }
}
