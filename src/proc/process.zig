//! Process management - process creation and scheduling
//! Provides process creation, context switching, and basic scheduling

const std = @import("std");
const common = @import("../common.zig");
const allocator = @import("../mm/allocator.zig");
const paging = @import("../mm/paging.zig");
const arch = @import("../arch/riscv32.zig");

const PageFlags = allocator.PageFlags;
const PAGE_SIZE = allocator.PAGE_SIZE;

const PROCS_MAX = 8;
const USER_BASE = 0x1000000;
const STACK_SIZE = 8192;

/// Process states
pub const ProcessState = enum(u32) {
    free = 0,
    runnable = 1,
    sleeping = 2,
    zombie = 3,
};

/// Process control block
pub const Process = struct {
    pid: usize,
    state: ProcessState,
    sp: u32,
    stack: [STACK_SIZE]u8,
    page_table: [*]u32,
    image_size: usize = 0,

    /// Create a new process
    pub fn create(entry_point: u32, image: ?[]const u8) !*Process {
        for (0..PROCS_MAX) |i| {
            if (procs[i].state == .free) {
                return try initProcess(i, entry_point, image);
            }
        }
        return error.NoFreeProcessSlots;
    }

    /// Initialize a process in the given slot
    fn initProcess(index: usize, entry: u32, image: ?[]const u8) !*Process {
        const p = &procs[index];

        // Set up stack pointer as [*]u32 aligned to word boundary
        var sp: [*]u32 = @ptrCast(@alignCast(&p.stack));
        sp += STACK_SIZE / @sizeOf(u32);

        // Push 13 callee-saved registers (s0-s11 + ra), zeroed
        for (0..13) |_| {
            sp -= 1;
            sp[0] = 0;
        }

        // Push return address (entry point)
        sp -= 1;
        sp[0] = entry;

        // Allocate and align page table
        const pt_slice = try allocator.allocPages(1);
        const pt: [*]u32 = @ptrCast(@alignCast(pt_slice.ptr));

        // Map kernel pages into user page table
        const kernel_base = @intFromPtr(@extern([*]u8, .{ .name = "__kernel_base" }));
        const free_ram_end = @intFromPtr(@extern([*]u8, .{ .name = "__free_ram_end" }));

        var paddr: u32 = @intCast(kernel_base);
        while (paddr < free_ram_end) : (paddr += PAGE_SIZE) {
            try paging.mapPage(pt, paddr, paddr,
                @intFromEnum(PageFlags.read) |
                @intFromEnum(PageFlags.write) |
                @intFromEnum(PageFlags.exec));
        }

        // Load image if provided
        if (image) |img| {
            var off: usize = 0;
            while (off < img.len) {
                const page = try allocator.allocPages(1);
                const copy_len = @min(PAGE_SIZE, img.len - off);
                @memcpy(page[0..copy_len], img[off..][0..copy_len]);
                const offset: u32 = @intCast(off);
                const vaddr = USER_BASE + offset;
                try paging.mapPage(pt, vaddr, @intFromPtr(page.ptr),
                    @intFromEnum(PageFlags.read) |
                    @intFromEnum(PageFlags.write) |
                    @intFromEnum(PageFlags.exec) |
                    @intFromEnum(PageFlags.user));

                off += PAGE_SIZE;
            }
            p.image_size = img.len;
        }

        p.* = .{
            .pid = index + 1,
            .state = .runnable,
            .sp = @intFromPtr(sp),
            .stack = undefined,
            .page_table = pt,
            .image_size = p.image_size,
        };

        return p;
    }

    /// Switch context between processes
    pub fn switchContext(prev_sp: *u32, next_sp: *u32) void {
        arch.switchContext(prev_sp, next_sp);
    }
};

/// Process scheduler
pub const Scheduler = struct {
    /// Initialize the scheduler with an idle process
    pub fn init() !void {
        idle_proc = try Process.create(0, null);
        if (idle_proc) |p| p.pid = 0;
        current_proc = idle_proc;
    }

    /// Yield CPU to the next runnable process
    pub fn yield() void {
        if (current_proc == null) return;

        var next = idle_proc;
        for (0..PROCS_MAX) |i| {
            const pid = current_proc.?.pid;
            const idx = @mod(pid + i, PROCS_MAX);
            const p = &procs[idx];

            if (p.state == .runnable and p.pid > 0) {
                next = p;
                break;
            }
        }

        if (next == current_proc) return;

        const prev = current_proc;
        current_proc = next;

        const SATP_SV32 = arch.SATP_SV32;

        asm volatile (
            \\sfence.vma
            \\csrw satp, %[satp]
            \\sfence.vma
            \\csrw sscratch, %[sscratch]
            :
            : [satp] "r" (SATP_SV32 | (@intFromPtr(next.?.page_table) / PAGE_SIZE)),
              [sscratch] "r" (@intFromPtr(&next.?.stack) + next.?.stack.len),
        );

        Process.switchContext(&prev.?.sp, &next.?.sp);
    }
};

/// Global process table and scheduler state
pub var procs: [PROCS_MAX]Process = undefined;
pub var current_proc: ?*Process = null;
pub var idle_proc: ?*Process = null;