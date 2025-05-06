const std = @import("std");
const common = @import("common.zig");

const PAGE_SIZE: u32 = 4096;

pub const PageFlags = enum(u32) {
    valid = 1 << 0,
    read = 1 << 1,
    write = 1 << 2,
    exec = 1 << 3,
    user = 1 << 4,
};

pub var next_free_paddr: u32 = undefined;

extern const __free_ram: [*]u8;
extern const __free_ram_end: [*]u8;

pub fn allocPages(n: u32) []u8 {
    if (n == 0)
        common.panic("cannot allocate 0 pages", .{});

    const paddr = next_free_paddr;
    const size = n * PAGE_SIZE;
    next_free_paddr += size;

    if (next_free_paddr > @intFromPtr(__free_ram_end)) {
        common.panic("out of memory", .{});
    }

    const ptr: [*]u8 = @ptrFromInt(paddr);
    @memset(ptr[0..size], 0);
    return ptr[0..size];
}

fn isAligned(addr: u32, size: u32) bool {
    return (addr & (size - 1)) == 0;
}

pub const PageTableEntry = struct {
    raw: u32,

    pub fn fromPhysical(paddr: u32, flags: u32) PageTableEntry {
        return .{ .raw = ((paddr / PAGE_SIZE) << 10) | (flags & 0x3FF) };
    }

    pub fn isValid(self: PageTableEntry) bool {
        return (self.raw & @intFromEnum(PageFlags.valid)) != 0;
    }

    pub fn getPhysicalAddress(self: PageTableEntry) u32 {
        return ((self.raw >> 10) & 0x3FFFFF) * PAGE_SIZE;
    }
};

pub fn mapPage(table1: [*]u32, vaddr: u32, paddr: u32, flags: u32) void {
    if (!isAligned(vaddr, PAGE_SIZE))
        common.panic("unaligned vaddr {x}", .{vaddr});
    if (!isAligned(paddr, PAGE_SIZE))
        common.panic("unaligned paddr {x}", .{paddr});

    const vpn1 = (vaddr >> 22) & 0x3FF;
    var pte1 = PageTableEntry{ .raw = table1[vpn1] };

    if (!pte1.isValid()) {
        const pt_pages = allocPages(1);
        pte1 = PageTableEntry.fromPhysical(@intFromPtr(pt_pages.ptr), @intFromEnum(PageFlags.valid));
        table1[vpn1] = pte1.raw;
    }

    const vpn0 = (vaddr >> 12) & 0x3FF;
    const table0: [*]u32 = @ptrFromInt(pte1.getPhysicalAddress());
    const pte0 = PageTableEntry.fromPhysical(paddr, flags | @intFromEnum(PageFlags.valid));
    table0[vpn0] = pte0.raw;
}
