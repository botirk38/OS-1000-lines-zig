const std = @import("std");
const allocator = @import("allocator");

const PAGE_SIZE = allocator.PAGE_SIZE;

/// RISC-V SV32 page-table entry permission bits.
pub const PageFlags = enum(u32) {
    valid = 1 << 0,
    read = 1 << 1,
    write = 1 << 2,
    exec = 1 << 3,
    user = 1 << 4,
};

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

    pub fn getFlags(self: PageTableEntry) u32 {
        return self.raw & 0x3FF;
    }
};

pub fn mapPage(table1: [*]u32, vaddr: u32, paddr: u32, flags: u32) void {
    if (!isAligned(vaddr, PAGE_SIZE)) @panic("Unaligned virtual address");
    if (!isAligned(paddr, PAGE_SIZE)) @panic("Unaligned physical address");

    const vpn1 = (vaddr >> 22) & 0x3FF;
    var pte1 = PageTableEntry{ .raw = table1[vpn1] };

    if (!pte1.isValid()) {
        const pt_paddr = allocator.allocPages(1);
        pte1 = PageTableEntry.fromPhysical(pt_paddr, @intFromEnum(PageFlags.valid));
        table1[vpn1] = pte1.raw;
    }

    const vpn0 = (vaddr >> 12) & 0x3FF;
    const table0: [*]u32 = @ptrFromInt(pte1.getPhysicalAddress());

    const pte0 = PageTableEntry.fromPhysical(paddr, flags | @intFromEnum(PageFlags.valid));
    table0[vpn0] = pte0.raw;
}

pub fn unmapPage(table1: [*]u32, vaddr: u32) void {
    if (!isAligned(vaddr, PAGE_SIZE)) @panic("Unaligned virtual address");

    const vpn1 = (vaddr >> 22) & 0x3FF;
    const pte1 = PageTableEntry{ .raw = table1[vpn1] };

    if (!pte1.isValid()) @panic("Page not mapped");

    const vpn0 = (vaddr >> 12) & 0x3FF;
    const table0: [*]u32 = @ptrFromInt(pte1.getPhysicalAddress());
    table0[vpn0] = 0;
}

fn isAligned(addr: u32, size: u32) bool {
    return (addr & (size - 1)) == 0;
}
