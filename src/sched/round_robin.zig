//! Round-robin cooperative scheduler.
//!
//! The scheduler owns the current and idle process pointers, and implements
//! the selection policy. It does not own the process table.

const arch = @import("arch");
const process = @import("process");
const log = @import("logger");

pub const Scheduler = struct {
    current: ?*process.Process = null,
    idle: ?*process.Process = null,

    pub fn init(self: *Scheduler) void {
        self.* = .{};
    }

    pub fn setIdle(self: *Scheduler, idle: *process.Process) void {
        self.idle = idle;
        self.current = idle;
    }

    pub fn currentProcess(self: *Scheduler) ?*process.Process {
        return self.current;
    }

    pub fn yield(self: *Scheduler, table: *process.Table) void {
        if (self.current == null) return;

        var next = self.idle;
        const current_pid = self.current.?.pid;

        for (0..process.PROCS_MAX) |i| {
            const idx = @mod(current_pid + i, process.PROCS_MAX);
            const p = &table.entries[idx];

            if (p.isRunnable()) {
                next = p;
                break;
            }
        }

        if (next == self.current) return;

        const prev = self.current;
        self.current = next;

        log.info("proc", "yield pid={} -> pid={}", .{ prev.?.pid, next.?.pid });
        log.debug("proc", "yield next.sp={x}", .{next.?.sp});

        const root = next.?.addressSpace();
        const stack_top = next.?.kernelStackTop();
        arch.Context.activateAddressSpace(root, stack_top);

        log.debug("proc", "switch_context prev.sp ptr={x} next.sp ptr={x}", .{
            @intFromPtr(&prev.?.sp),
            @intFromPtr(&next.?.sp),
        });

        arch.Context.swap(&prev.?.sp, &next.?.sp);

        log.debug("proc", "switch_context returned (back to pid={})", .{self.current.?.pid});
    }
};
