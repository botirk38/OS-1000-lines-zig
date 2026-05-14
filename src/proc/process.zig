//! Process management.
//! Defines the concrete Process type and the process Table.
//! Scheduling policy lives in the scheduler module.

const allocator = @import("allocator");
const layout = @import("layout");
const arch = @import("arch");
const virtio = @import("virtio");
const log = @import("logger");

const PAGE_SIZE = layout.PAGE_SIZE;

extern const __kernel_base: [*]u8;
extern const __free_ram_end: [*]u8;
extern fn user_entry() void;

pub const PROCS_MAX = 8;
const USER_BASE = layout.USER_BASE;
const STACK_SIZE = layout.STACK_SIZE;

pub const State = enum(u2) {
    unused = 0,
    runnable = 1,
    exited = 2,
};

pub const Error = error{
    NoFreeSlot,
} || arch.PagingError || allocator.AllocError;

pub const Process = struct {
    pid: usize,
    state: State,
    sp: arch.Word,
    stack: [STACK_SIZE / @sizeOf(arch.Word)]arch.Word,
    page_table: [*]arch.Word,

    pub fn isRunnable(self: *const Process) bool {
        return self.state == .runnable and self.pid > 0;
    }

    pub fn markExited(self: *Process) void {
        self.state = .exited;
    }

    pub fn addressSpace(self: *Process) arch.Paging.Root {
        return arch.Paging.rootFromPtr(self.page_table);
    }

    pub fn kernelStackTop(self: *Process) arch.Word {
        return @intCast(@intFromPtr(&self.stack) + STACK_SIZE);
    }
};

pub const Table = struct {
    entries: [PROCS_MAX]Process,

    pub fn init(self: *Table) void {
        for (0..PROCS_MAX) |i| {
            self.entries[i] = Process{
                .pid = 0,
                .state = .unused,
                .sp = 0,
                .stack = undefined,
                .page_table = undefined,
            };
        }
    }

    pub fn createIdle(self: *Table) Error!*Process {
        const p = try self.create(&.{});
        p.pid = 0;
        return p;
    }

    pub fn createUser(self: *Table, image: []const u8) Error!*Process {
        return self.create(image);
    }

    fn create(self: *Table, image: []const u8) (Error || arch.PagingError || allocator.AllocError)!*Process {
        var slot_index: usize = 0;
        var proc: ?*Process = null;
        while (slot_index < PROCS_MAX) : (slot_index += 1) {
            if (self.entries[slot_index].state == .unused) {
                proc = &self.entries[slot_index];
                break;
            }
        }

        if (proc == null) {
            return error.NoFreeSlot;
        }

        const p = proc.?;

        // Build fake context frame on the kernel stack
        const ContextFrame = packed struct {
            ra: u32,
            s0: u32,
            s1: u32,
            s2: u32,
            s3: u32,
            s4: u32,
            s5: u32,
            s6: u32,
            s7: u32,
            s8: u32,
            s9: u32,
            s10: u32,
            s11: u32,
        };

        const frame_size = @sizeOf(ContextFrame);
        const stack_top = @intFromPtr(&p.stack) + STACK_SIZE;
        const frame_addr = stack_top - frame_size;
        const frame: *ContextFrame = @ptrFromInt(frame_addr);

        frame.* = .{
            .ra = @intFromPtr(&user_entry),
            .s0 = 0,
            .s1 = 0,
            .s2 = 0,
            .s3 = 0,
            .s4 = 0,
            .s5 = 0,
            .s6 = 0,
            .s7 = 0,
            .s8 = 0,
            .s9 = 0,
            .s10 = 0,
            .s11 = 0,
        };

        const saved_sp: arch.Word = @intCast(frame_addr);

        // Allocate and populate page table
        const pt_paddr = try allocator.allocPages(1);
        const pt: [*]arch.Word = @ptrFromInt(pt_paddr);

        // Map all kernel pages
        const kernel_base: u32 = @intCast(@intFromPtr(&__kernel_base));
        const free_ram_end: u32 = @intCast(@intFromPtr(&__free_ram_end));

        log.info("proc", "create: mapping kernel_base={x} .. free_ram_end={x}", .{ kernel_base, free_ram_end });

        const root = arch.Paging.rootFromPtr(pt);
        var paddr: u32 = kernel_base;
        while (paddr < free_ram_end) : (paddr += PAGE_SIZE) {
            try arch.Paging.map(
                root,
                @enumFromInt(paddr),
                @enumFromInt(paddr),
                &.{ .read, .write, .exec },
            );
        }

        // Map VirtIO block device MMIO region
        try arch.Paging.map(
            root,
            @enumFromInt(virtio.VIRTIO_BLK_PADDR),
            @enumFromInt(virtio.VIRTIO_BLK_PADDR),
            &.{ .read, .write },
        );

        // Map user image pages
        if (image.len > 0) {
            var off: usize = 0;
            while (off < image.len) : (off += PAGE_SIZE) {
                const page_paddr = try allocator.allocPages(1);
                const page: [*]u8 = @ptrFromInt(page_paddr);
                const copy_len = @min(PAGE_SIZE, image.len - off);
                @memcpy(page[0..copy_len], image[off..][0..copy_len]);

                const vaddr = USER_BASE + @as(u32, @intCast(off));
                try arch.Paging.map(
                    root,
                    @enumFromInt(vaddr),
                    @enumFromInt(page_paddr),
                    &.{ .read, .write, .exec, .user },
                );
            }
        }

        // Populate process struct
        p.pid = slot_index + 1;
        p.state = .runnable;
        p.sp = saved_sp;
        p.page_table = pt;

        log.debug("proc", "create pid={} sp={x} page_table={x}", .{ p.pid, p.sp, @intFromPtr(p.page_table) });

        return p;
    }
};
