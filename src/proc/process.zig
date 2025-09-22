//! Process management - process creation and scheduling
//! Provides process creation, context switching, and basic scheduling

const std = @import("std");
const common = @import("../common.zig");
const allocator = @import("../mm/allocator.zig");
const paging = @import("../mm/paging.zig");
const arch = @import("../arch/riscv32.zig");

const PageFlags = allocator.PageFlags;
const PAGE_SIZE = allocator.PAGE_SIZE;

extern const __kernel_base: [*]u8;
extern const __free_ram_end: [*]u8;

pub const PROCS_MAX = 8;
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
        const scheduler = @import("scheduler.zig");
        for (0..PROCS_MAX) |i| {
            if (scheduler.procs[i].state == .free) {
                return initProcess(i, entry_point, image);
            }
        }
        return error.NoFreeProcessSlots;
    }

    /// Initialize a process in the given slot
    fn initProcess(index: usize, entry: u32, image: ?[]const u8) *Process {
        common.printf("[rk] initProcess: starting...\n", .{});
        const scheduler = @import("scheduler.zig");
        const p = &scheduler.procs[index];

        common.printf("[rk] initProcess: setting up stack...\n", .{});
        // Set up stack pointer as [*]u32 aligned to word boundary
        var sp: [*]u32 = @ptrCast(@alignCast(&p.stack));
        sp += STACK_SIZE / @sizeOf(u32);

        // Push 13 callee-saved registers (s0-s11 + ra), zeroed
        for (0..13) |_| {
            sp -= 1;
            sp[0] = 0;
        }

        // Push return address (user_entry for user processes, 0 for idle process)
        sp -= 1;
        if (entry == 0) {
            sp[0] = 0; // idle process
        } else {
            // Get user_entry function address from kernel
            const user_entry = @extern(*const fn () callconv(.naked) void, .{ .name = "user_entry" });
            sp[0] = @intFromPtr(user_entry);
        }

        common.printf("[rk] initProcess: allocating page table...\n", .{});
        // Allocate and align page table
        const pt_paddr = allocator.allocPages(1);
        const pt: [*]u32 = @ptrFromInt(pt_paddr);

        common.printf("[rk] initProcess: mapping kernel pages...\n", .{});
        // Map kernel pages into user page table
        const kernel_base_sym = @extern([*]u8, .{ .name = "__kernel_base" });
        const free_ram_end_sym = @extern([*]u8, .{ .name = "__free_ram_end" });
        const kernel_base = @intFromPtr(kernel_base_sym);
        const free_ram_end = @intFromPtr(free_ram_end_sym);

        common.printf("[rk] kernel_base={x}, free_ram_end={x}\n", .{ kernel_base, free_ram_end });
        var paddr: u32 = @intCast(kernel_base);
        common.printf("[rk] starting memory mapping loop...\n", .{});
        while (paddr < free_ram_end) : (paddr += PAGE_SIZE) {
            paging.mapPage(pt, paddr, paddr, @intFromEnum(PageFlags.read) |
                @intFromEnum(PageFlags.write) |
                @intFromEnum(PageFlags.exec));
        }
        common.printf("[rk] memory mapping complete\n", .{});

        // Load image if provided
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
