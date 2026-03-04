const process = @import("process");
const log = @import("logger");

pub fn exit(code: i32) noreturn {
    if (process.current_proc) |p| {
        // Mark process as exited and yield to scheduler
        p.state = .exited;
        log.info("proc", "process {} exited with code {}", .{ p.pid, code });
    }
    // Yield in a loop: yield() may return if no other process is runnable,
    // but we must never execute user code again after exit.
    while (true) {
        process.yield();
    }
}

pub fn yield() void {
    process.yield();
}

pub fn getpid() u32 {
    if (process.current_proc) |p| return @intCast(p.pid);
    return 0;
}
