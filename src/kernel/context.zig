//! Root kernel context.
//!
//! Owns all kernel subsystems and provides a single point of access for
//! scheduler operations and process management.

const process = @import("process");
const scheduler = @import("scheduler");

var active: ?*Context = null;

pub const Context = struct {
    processes: process.Table,
    sched: scheduler.Scheduler,

    pub fn init(self: *Context) void {
        self.processes.init();
        self.sched.init();
    }

    pub fn install(self: *Context) void {
        active = self;
    }

    pub fn current() *Context {
        return active orelse unreachable;
    }

    pub fn createIdle(self: *Context) !void {
        const idle = try self.processes.createIdle();
        self.sched.setIdle(idle);
    }

    pub fn createUser(self: *Context, image: []const u8) !void {
        _ = try self.processes.createUser(image);
    }

    pub fn yield(self: *Context) void {
        self.sched.yield(&self.processes);
    }

    pub fn currentProcess(self: *Context) ?*process.Process {
        return self.sched.currentProcess();
    }
};
