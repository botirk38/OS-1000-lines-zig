//! Process scheduler - handles process switching and CPU time management
//! Implements cooperative multitasking with round-robin scheduling

const std = @import("std");
const fmt = @import("fmt");
const arch = @import("arch");
const process = @import("process");
const allocator = @import("allocator");

/// Global process table and scheduler state
pub var procs: [process.PROCS_MAX]process.Process = undefined;
pub var current_proc: ?*process.Process = null;
pub var idle_proc: ?*process.Process = null;

/// Process scheduler implementing cooperative round-robin scheduling.
/// Maintains global process table and handles context switching between processes.
pub const Scheduler = struct {
    /// Initialize the scheduler and create the idle process.
    /// Must be called once at kernel startup before creating user processes.
    pub fn init() !void {
        // Initialize process table - all processes start as free
        for (0..process.PROCS_MAX) |i| {
            procs[i] = process.Process{
                .pid = 0,
                .state = .free,
                .sp = 0,
                .stack = undefined,
                .page_table = undefined,
                .image_size = 0,
            };
        }

        // Create idle process with NULL entry point (as per documentation)
        idle_proc = process.Process.create(0, null) catch |err| {
            fmt.printf("[PANIC] Failed to create idle process: {}\n", .{err});
            @panic("Failed to create idle process");
        };
        if (idle_proc) |p| p.pid = 0;
        current_proc = idle_proc;
    }

    /// Yield CPU to the next runnable process using round-robin scheduling.
    /// Switches page tables and performs context switch to the selected process.
    /// If no runnable process is found, switches to the idle process.
    pub fn yield() void {
        if (current_proc == null) return;

        // Search for a runnable process
        var next = idle_proc;
        for (0..process.PROCS_MAX) |i| {
            const pid = current_proc.?.pid;
            const idx = @mod(pid + i, process.PROCS_MAX);
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
            : [satp] "r" (SATP_SV32 | (@intFromPtr(next.?.page_table) / allocator.PAGE_SIZE)),
              [sscratch] "r" (@intFromPtr(&next.?.stack) + next.?.stack.len),
        );

        process.Process.switchContext(&prev.?.sp, &next.?.sp);

        // Add delay after context switch for more readable output
        delay();
    }
};

/// Delay function for testing
pub fn delay() void {
    for (0..60_000_000) |_| {
        asm volatile ("nop");
    }
}
