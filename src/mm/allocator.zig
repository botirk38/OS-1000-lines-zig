const std = @import("std");
const layout = @import("layout");

pub const PAGE_SIZE: u32 = layout.PAGE_SIZE;

var next_free_paddr: u32 = undefined;

pub fn init(free_ram_start: u32) void {
    next_free_paddr = free_ram_start;
}

pub fn allocPages(n: u32) u32 {
    if (n == 0) {
        @panic("Invalid page count");
    }

    const paddr = next_free_paddr;
    const size = n * PAGE_SIZE;
    next_free_paddr += size;

    const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });
    const end_addr = @intFromPtr(free_ram_end);

    if (next_free_paddr > end_addr) {
        @panic("Out of memory");
    }

    const ptr: [*]u8 = @ptrFromInt(paddr);
    @memset(ptr[0..size], 0);

    return paddr;
}
