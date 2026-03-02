const process = @import("process");
const console = @import("console");

pub fn exit(code: i32) noreturn {
    if (process.current_proc) |p| {
        p.exit_code = code;
        p.state = .zombie;
        console.printf("[kernel] process {} exited with code {}\n", .{ p.pid, code });
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
