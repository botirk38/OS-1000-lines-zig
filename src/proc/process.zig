//! Process management and scheduler.
//! Owns the global process table, current/idle process pointers,
//! and all scheduling logic (cooperative round-robin).
//! Logic mirrors the C reference implementation exactly.

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

/// Process states: match C reference (PROC_UNUSED, PROC_RUNNABLE, PROC_EXITED)
pub const ProcessState = enum(u2) {
    unused = 0,
    runnable = 1,
    exited = 2,
};

/// Process structure: matches C struct process exactly
pub const ProcessError = error{
    NoFreeSlot,
};

pub const Process = struct {
    pid: usize,
    state: ProcessState,
    sp: u32,
    stack: [STACK_SIZE / @sizeOf(u32)]u32, // u32 array ensures 4-byte alignment
    page_table: [*]u32,

    /// Allocate and initialize a new process slot. `image` may be empty for an idle process.
    /// Errors if no free slots remain or if paging/allocator operations fail.
    pub fn create(image: []const u8) (ProcessError || arch.PagingError || allocator.AllocError)!*Process {
        // Find first free slot (search from 0, like C)
        var slot_index: usize = 0;
        var proc: ?*Process = null;
        while (slot_index < PROCS_MAX) : (slot_index += 1) {
            if (procs[slot_index].state == .unused) {
                proc = &procs[slot_index];
                break;
            }
        }

        if (proc == null) {
            return error.NoFreeSlot;
        }

        const p = proc.?;

        // Build fake context frame on the kernel stack.
        // C: uint32_t *sp = (uint32_t *) &proc->stack[sizeof(proc->stack)];
        // Then: *--sp = 0 (x12 times for s11..s0), *--sp = (uint32_t)user_entry
        //
        // We do the same but via the SwitchFrame struct written at the top of the stack.
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

        // Place the frame at the top of the stack
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

        const saved_sp: u32 = @intCast(frame_addr);

        // Allocate and populate page table
        const pt_paddr = try allocator.allocPages(1);
        const pt: [*]u32 = @ptrFromInt(pt_paddr);

        // Map all kernel pages — identity-map kernel code/data/stack/heap
        // (matches C reference: __kernel_base .. __free_ram_end).
        // This is necessary so that the kernel stack, process table, and
        // allocator pages remain accessible after csrw satp switches page tables.
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

        // Map user image pages (if provided)
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

/// Create idle process (slot 0, pid=0, no user image).
/// Panics on failure because the kernel cannot function without an idle process.
pub fn createIdle() *Process {
    const p = Process.create(&.{}) catch |err| {
        log.err("proc", "createIdle failed: {}", .{err});
        @panic("failed to create idle process");
    };
    p.pid = 0;
    return p;
}

/// Create a user process from a binary image.
/// Returns null if no slots remain.
pub fn createUser(image: []const u8) ?*Process {
    return Process.create(image) catch |err| {
        log.err("proc", "createUser failed: {}", .{err});
        return null;
    };
}

// ---------------------------------------------------------------------------
// Global scheduler state
// ---------------------------------------------------------------------------

var procs: [PROCS_MAX]Process = undefined;
pub var current_proc: ?*Process = null;
var idle_proc: ?*Process = null;

/// Initialize the process table (zero all slots).
pub fn init() void {
    for (0..PROCS_MAX) |i| {
        procs[i] = Process{
            .pid = 0,
            .state = .unused,
            .sp = 0,
            .stack = undefined,
            .page_table = undefined,
        };
    }
}

/// Yield CPU to the next runnable process using round-robin scheduling.
pub fn yield() void {
    if (current_proc == null) return;

    var next = idle_proc;
    const current_pid = current_proc.?.pid;

    for (0..PROCS_MAX) |i| {
        const idx = @mod(current_pid + i, PROCS_MAX);
        const p = &procs[idx];

        if (p.state == .runnable and p.pid > 0) {
            next = p;
            break;
        }
    }

    if (next == current_proc) {
        return;
    }

    const prev = current_proc;
    current_proc = next;

    const next_sp_val = next.?.sp;
    const ra_at_sp: u32 = @as(*const u32, @ptrFromInt(next_sp_val)).*;
    log.info("proc", "yield pid={} -> pid={}", .{ prev.?.pid, next.?.pid });
    log.debug("proc", "yield next.sp={x} ra_at_sp={x}", .{
        next_sp_val,
        ra_at_sp,
    });

    const root = arch.Paging.rootFromPtr(next.?.page_table);
    const stack_top = @intFromPtr(&next.?.stack) + STACK_SIZE;
    arch.Context.activateAddressSpace(root, stack_top);

    log.debug("proc", "switch_context prev.sp ptr={x} next.sp ptr={x}", .{
        @intFromPtr(&prev.?.sp),
        @intFromPtr(&next.?.sp),
    });

    arch.Context.swap(&prev.?.sp, &next.?.sp);

    log.debug("proc", "switch_context returned (back to pid={})", .{current_proc.?.pid});
}
