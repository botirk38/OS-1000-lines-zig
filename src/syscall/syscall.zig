const arch = @import("arch");
const io = @import("io.zig");
const proc = @import("proc.zig");

pub const SysCall = enum(u32) {
    write = 1,
    read = 2,
    exit = 3,
    yield = 4,
    _,
};

pub fn dispatch(frame: *arch.TrapFrame) void {
    const syscall_enum: SysCall = @enumFromInt(frame.a7);

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
        else => {
            frame.a0 = @bitCast(@as(i32, -1));
        },
    }
}
