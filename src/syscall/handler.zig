const arch = @import("../arch/riscv32.zig");
const io = @import("io.zig");
const proc = @import("proc.zig");
const numbers = @import("numbers.zig");

pub fn dispatch(frame: *arch.TrapFrame) void {
    const syscall_num = frame.a7;

    switch (syscall_num) {
        numbers.SYS_write => {
            frame.a0 = @bitCast(io.write(frame.a0, frame.a1, frame.a2));
        },
        numbers.SYS_exit => {
            proc.exit(@bitCast(frame.a0));
        },
        numbers.SYS_yield => {
            proc.yield();
        },
        else => {
            frame.a0 = @bitCast(@as(i32, -1));
        },
    }
}
