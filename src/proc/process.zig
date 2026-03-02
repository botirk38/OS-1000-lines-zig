//! Process management and scheduler.
//! Owns the global process table, current/idle process pointers,
//! and all scheduling logic (cooperative round-robin).

const allocator = @import("allocator");
const paging = @import("paging");
const layout = @import("layout");
const arch = @import("arch");
const virtio = @import("virtio");

const PageFlags = paging.PageFlags;
const PAGE_SIZE = layout.PAGE_SIZE;

extern const __kernel_base: [*]u8;
extern const __free_ram_end: [*]u8;
extern fn user_entry() callconv(.naked) void;

pub const PROCS_MAX = 8;
const USER_BASE = layout.USER_BASE;
const STACK_SIZE = layout.STACK_SIZE;

pub const ProcessState = enum(u32) {
    free = 0,
    runnable = 1,
    sleeping = 2,
    zombie = 3,
};

pub const Process = struct {
    pid: usize,
    state: ProcessState,
    sp: u32,
    stack: [STACK_SIZE]u8,
    page_table: [*]u32,
    image_size: usize = 0,
    exit_code: i32 = 0,

    pub fn create(entry_point: u32, image: ?[]const u8) !*Process {
        // Slot 0 is reserved for the idle process; user processes start at 1.
        for (1..PROCS_MAX) |i| {
            if (procs[i].state == .free) {
                return initProcess(i, entry_point, image);
            }
        }
        return error.NoFreeProcessSlots;
    }

    /// Lightweight init for the idle process: no page table, no mappings.
    /// Just builds the 13-word context frame with ra=0 so switchContext
    /// will simply spin (never actually reached for idle — yield returns early).
    fn initIdle(index: usize) *Process {
        const p = &procs[index];

        var sp: [*]u32 = @ptrCast(@alignCast(&p.stack));
        sp += STACK_SIZE / @sizeOf(u32);

        // Push 12 callee-saved regs (s0–s11) as zero
        for (0..12) |_| {
            sp -= 1;
            sp[0] = 0;
        }
        // Push ra = 0 (idle never returns anywhere)
        sp -= 1;
        sp[0] = 0;

        const saved_sp: u32 = @intCast(@intFromPtr(sp));

        p.pid = 0;
        p.state = .runnable;
        p.sp = saved_sp;
        // page_table intentionally left undefined — idle process never runs
        // user code and yield() exits early before touching satp for idle.

        return p;
    }

    fn initProcess(index: usize, entry: u32, image: ?[]const u8) *Process {
        const p = &procs[index];

        // sp starts at the top of the stack (one past the last u32)
        var sp: [*]u32 = @ptrCast(@alignCast(&p.stack));
        sp += STACK_SIZE / @sizeOf(u32);

        // Push context frame matching switchContext layout (13 words):
        //   offset 12 = s11, offset 11 = s10, ..., offset 1 = s0, offset 0 = ra
        // Push s11 down to s0 (12 callee-saved regs, all zero for fresh process)
        for (0..12) |_| {
            sp -= 1;
            sp[0] = 0;
        }

        // Push ra: user_entry for user processes, 0 for idle
        sp -= 1;
        if (entry != 0) {
            sp[0] = @intFromPtr(&user_entry);
        } else {
            sp[0] = 0;
        }

        // Save the final sp value before we set up the Process struct.
        // IMPORTANT: do NOT assign .stack = undefined after this point — it
        // would overwrite the context frame we just built.
        const saved_sp: u32 = @intCast(@intFromPtr(sp));

        const pt_paddr = allocator.allocPages(1);
        const pt: [*]u32 = @ptrFromInt(pt_paddr);

        const kernel_base = @intFromPtr(&__kernel_base);
        const free_ram_end = @intFromPtr(&__free_ram_end);

        var paddr: u32 = @intCast(kernel_base);
        while (paddr < free_ram_end) : (paddr += PAGE_SIZE) {
            paging.mapPage(pt, paddr, paddr, @intFromEnum(PageFlags.read) |
                @intFromEnum(PageFlags.write) |
                @intFromEnum(PageFlags.exec));
        }

        paging.mapPage(pt, virtio.VIRTIO_BLK_PADDR, virtio.VIRTIO_BLK_PADDR, @intFromEnum(PageFlags.read) | @intFromEnum(PageFlags.write));

        if (image) |img| {
            var off: usize = 0;
            while (off < img.len) {
                const page_paddr = allocator.allocPages(1);
                const page: [*]u8 = @ptrFromInt(page_paddr);
                const copy_len = @min(PAGE_SIZE, img.len - off);
                @memcpy(page[0..copy_len], img[off..][0..copy_len]);
                const offset: u32 = @intCast(off);
                const vaddr = USER_BASE + offset;
                paging.mapPage(pt, vaddr, page_paddr, @intFromEnum(PageFlags.read) |
                    @intFromEnum(PageFlags.write) |
                    @intFromEnum(PageFlags.exec) |
                    @intFromEnum(PageFlags.user));

                off += PAGE_SIZE;
            }
            p.image_size = img.len;
        }

        // Set scalar fields only — do NOT touch p.stack here
        p.pid = index;
        p.state = .runnable;
        p.sp = saved_sp;
        p.page_table = pt;

        return p;
    }
};

// ---------------------------------------------------------------------------
// Global scheduler state
// ---------------------------------------------------------------------------

pub var procs: [PROCS_MAX]Process = undefined;
pub var current_proc: ?*Process = null;
pub var idle_proc: ?*Process = null;

/// Initialize process table and create the idle process.
/// Must be called once at kernel startup before creating user processes.
pub fn initScheduler() !void {
    for (0..PROCS_MAX) |i| {
        procs[i] = Process{
            .pid = 0,
            .state = .free,
            .sp = 0,
            .stack = undefined,
            .page_table = undefined,
            .image_size = 0,
            .exit_code = 0,
        };
    }

    // Slot 0 is reserved for the idle process — use lightweight init.
    idle_proc = Process.initIdle(0);
    current_proc = idle_proc;
}

/// Yield CPU to the next runnable process using round-robin scheduling.
pub fn yield() void {
    if (current_proc == null) return;

    var next = idle_proc;
    const pid = current_proc.?.pid;
    for (1..PROCS_MAX) |i| {
        const idx = @mod(pid + i, PROCS_MAX);
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

    asm volatile (
        \\sfence.vma
        \\csrw satp, %[satp]
        \\sfence.vma
        \\csrw sscratch, %[sscratch]
        :
        : [satp] "r" (arch.SATP_SV32 | (@intFromPtr(next.?.page_table) / allocator.PAGE_SIZE)),
          [sscratch] "r" (@intFromPtr(&next.?.stack) + next.?.stack.len),
    );

    @as(*const fn (*u32, *u32) callconv(.c) void, @ptrCast(&arch.switchContext))(&prev.?.sp, &next.?.sp);
}
