const process = @import("process");
const scheduler = @import("scheduler");

pub fn exit(code: i32) noreturn {
    _ = code;

    if (scheduler.current_proc) |p| {
        p.state = process.ProcessState.zombie;
    }

    scheduler.Scheduler.yield();
    @panic("sys_exit returned unexpectedly");
}

pub fn yield() void {
    scheduler.Scheduler.yield();
}
