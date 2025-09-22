//! Memory management - page allocator implementation
//! Provides a simple bump allocator for kernel memory allocation

const std = @import("std");
const common = @import("../common.zig");

pub const PAGE_SIZE: u32 = 4096;

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

/// External memory layout symbols from linker script
extern const __free_ram: [*]u8;
extern const __free_ram_end: [*]u8;

/// Initialize the allocator with the free memory region
pub fn init(free_ram_start: u32) void {
    next_free_paddr = free_ram_start;
}

/// Allocate n pages of memory
pub fn allocPages(n: u32) ![]u8 {
    if (n == 0) return error.InvalidPageCount;

    const paddr = next_free_paddr;
    const size = n * PAGE_SIZE;
    next_free_paddr += size;

    if (next_free_paddr > @intFromPtr(__free_ram_end)) {
        return error.OutOfMemory;
    }

    const ptr: [*]u8 = @ptrFromInt(paddr);
    @memset(ptr[0..size], 0);
    return ptr[0..size];
}

/// Get current memory usage statistics
pub fn getStats() struct { used: u32, total: u32, free: u32 } {
    const start = @intFromPtr(__free_ram);
    const end = @intFromPtr(__free_ram_end);
    const total = end - start;
    const used = next_free_paddr - start;
    const free = total - used;

    return .{ .used = used, .total = total, .free = free };
}

