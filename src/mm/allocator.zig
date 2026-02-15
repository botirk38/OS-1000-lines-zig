//! Memory management - page allocator implementation
//! Provides a simple bump allocator for kernel memory allocation

const std = @import("std");
const fmt = @import("fmt");
const layout = @import("layout");

pub const PAGE_SIZE: u32 = layout.PAGE_SIZE;

/// Page flags for memory mapping
pub const PageFlags = enum(u32) {
    valid = 1 << 0,
    read = 1 << 1,
    write = 1 << 2,
    exec = 1 << 3,
    user = 1 << 4,
};

/// Global allocator state
var next_free_paddr: u32 = undefined;

// External memory layout symbols from linker script will be accessed via @extern

/// Initialize the allocator with the free memory region.
/// Must be called once at kernel startup before any allocations.
pub fn init(free_ram_start: u32) void {
    fmt.printf("[allocator] init: free_ram_start={x}\n", .{free_ram_start});
    next_free_paddr = free_ram_start;
    fmt.printf("[allocator] init: next_free_paddr={x}\n", .{next_free_paddr});
}

/// Allocate n pages of memory and return physical address.
/// Pages are zeroed before being returned.
/// Panics if out of memory or if n is 0.
pub fn allocPages(n: u32) u32 {
    fmt.printf("[allocator] allocPages: n={}, PAGE_SIZE={}\n", .{ n, PAGE_SIZE });

    if (n == 0) {
        @panic("Invalid page count");
    }

    const paddr = next_free_paddr;
    const size = n * PAGE_SIZE;
    fmt.printf("[allocator] allocPages: paddr={x}, size={x}\n", .{ paddr, size });

    next_free_paddr += size;
    fmt.printf("[allocator] allocPages: new next_free_paddr={x}\n", .{next_free_paddr});

    const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });
    const end_addr = @intFromPtr(free_ram_end);
    fmt.printf("[allocator] allocPages: checking bounds, end_addr={x}\n", .{end_addr});

    if (next_free_paddr > end_addr) {
        @panic("Out of memory");
    }

    // Check if the memory region is valid
    const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
    const start_addr = @intFromPtr(free_ram);
    fmt.printf("[allocator] allocPages: start_addr={x}\n", .{start_addr});

    if (paddr < start_addr or paddr >= end_addr) {
        @panic("Invalid memory address range");
    }

    fmt.printf("[allocator] allocPages: creating pointer from paddr={x}\n", .{paddr});
    const ptr: [*]u8 = @ptrFromInt(paddr);

    fmt.printf("[allocator] allocPages: calling @memset, size={}\n", .{size});
    @memset(ptr[0..size], 0);

    fmt.printf("[allocator] allocPages: returning paddr={x}\n", .{paddr});
    return paddr;
}

/// Get current memory usage statistics
pub fn getStats() struct { used: u32, total: u32, free: u32 } {
    const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
    const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });
    const start = @intFromPtr(free_ram);
    const end = @intFromPtr(free_ram_end);
    const total = end - start;
    const used = next_free_paddr - start;
    const free = total - used;

    return .{ .used = used, .total = total, .free = free };
}
