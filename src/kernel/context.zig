//! Root kernel context.
//!
//! Owns all kernel subsystems and provides a single point of access for
//! trap handling, syscall dispatch, and scheduler operations.

const arch = @import("arch");
const process = @import("process");
const scheduler = @import("scheduler");
const log = @import("logger");
const sbi = @import("sbi");
const fs = @import("fs");
const panic_lib = @import("panic");

pub const Syscall = enum(u32) {
    write = 1,
    read = 2,
    exit = 3,
    yield = 4,
    getpid = 5,
    readfile = 6,
    writefile = 7,
    _,
};

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

    pub fn handleTrap(self: *Context, frame: *arch.Trap.Frame) void {
        const trap = arch.Trap.read();

        log.debug("trap", "handleTrap kind={s} cause={x} pc={x} stval={x}", .{
            switch (trap.kind) {
                .exception => |e| @tagName(e),
                .interrupt => |i| @tagName(i),
            },
            trap.cause,
            trap.pc,
            trap.value,
        });

        switch (trap.kind) {
            .exception => |exception| switch (exception) {
                .user_syscall => {
                    self.handleSyscall(frame);
                    arch.Trap.setPc(trap.pc + 4);
                    return;
                },
                else => {},
            },
            .interrupt => |interrupt| switch (interrupt) {
                else => {},
            },
        }

        panic_lib.panic("trap: cause={x}, stval={x}, sepc={x}, ra={x}, sp={x}", .{
            trap.cause,
            trap.value,
            trap.pc,
            frame.ra,
            frame.sp,
        });
    }

    fn handleSyscall(self: *Context, frame: *arch.Trap.Frame) void {
        const syscall_enum: Syscall = @enumFromInt(arch.Syscall.number(frame));

        log.debug("syscall", "syscall={s} a0={x} a1={x} a2={x}", .{
            @tagName(syscall_enum),
            arch.Syscall.arg(frame, 0),
            arch.Syscall.arg(frame, 1),
            arch.Syscall.arg(frame, 2),
        });

        switch (syscall_enum) {
            .write => {
                arch.Syscall.setReturn(frame, @bitCast(self.syscallWrite(frame)));
            },
            .read => {
                arch.Syscall.setReturn(frame, @bitCast(self.syscallRead(frame)));
            },
            .exit => {
                self.syscallExit(@bitCast(arch.Syscall.arg(frame, 0)));
            },
            .yield => {
                self.yield();
            },
            .getpid => {
                arch.Syscall.setReturn(frame, self.syscallGetpid());
            },
            .readfile => {
                arch.Syscall.setReturn(frame, @bitCast(self.syscallReadFile(frame)));
            },
            .writefile => {
                arch.Syscall.setReturn(frame, @bitCast(self.syscallWriteFile(frame)));
            },
            else => {
                arch.Syscall.setReturn(frame, @bitCast(@as(i32, -1)));
            },
        }
    }

    fn syscallWrite(_: *Context, frame: *arch.Trap.Frame) i32 {
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

    fn syscallRead(_: *Context, frame: *arch.Trap.Frame) i32 {
        const fd = arch.Syscall.arg(frame, 0);
        const buf = arch.Syscall.arg(frame, 1);
        const len = arch.Syscall.arg(frame, 2);

        if (fd != 0) return -1;
        if (len == 0) return 0;

        const ptr: [*]u8 = @ptrFromInt(buf);
        const ch = while (true) {
            const c = sbi.getChar();
            if (c >= 0) break c;
            // Would need scheduler access to yield properly here
            // For now, busy wait to avoid circular dependency
        };

        ptr[0] = @intCast(ch);
        return 1;
    }

    fn syscallExit(self: *Context, code: i32) noreturn {
        if (self.currentProcess()) |p| {
            p.markExited();
            log.info("proc", "process {} exited with code {}", .{ p.pid, code });
        }
        while (true) {
            self.yield();
        }
    }

    fn syscallGetpid(self: *Context) u32 {
        if (self.currentProcess()) |p| return @intCast(p.pid);
        return 0;
    }

    fn syscallReadFile(_: *Context, frame: *arch.Trap.Frame) i32 {
        const filename: [*:0]const u8 = @ptrFromInt(arch.Syscall.arg(frame, 0));
        const buf: [*]u8 = @ptrFromInt(arch.Syscall.arg(frame, 1));
        const len: usize = @truncate(arch.Syscall.arg(frame, 2));

        const file = fs.lookup(filename) orelse return -1;
        const copy_len = @min(len, file.size);
        @memcpy(buf[0..copy_len], file.data[0..copy_len]);
        return @intCast(copy_len);
    }

    fn syscallWriteFile(_: *Context, frame: *arch.Trap.Frame) i32 {
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
};
