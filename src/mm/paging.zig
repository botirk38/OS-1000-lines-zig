const std = @import("std");
const allocator = @import("allocator");
const arch = @import("arch");

const PAGE_SIZE = allocator.PAGE_SIZE;
const sv32 = arch.sv32;

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
        return .{ .raw = ((paddr / PAGE_SIZE) << sv32.PTE_PPN_SHIFT) | (flags & sv32.PTE_FLAGS_MASK) };
    }

    pub fn isValid(self: PageTableEntry) bool {
        return (self.raw & @intFromEnum(PageFlags.valid)) != 0;
    }

    pub fn getPhysicalAddress(self: PageTableEntry) u32 {
        return ((self.raw >> sv32.PTE_PPN_SHIFT) & sv32.PTE_PPN_MASK) * PAGE_SIZE;
    }

    pub fn getFlags(self: PageTableEntry) u32 {
        return self.raw & sv32.PTE_FLAGS_MASK;
    }
};

pub fn mapPage(table1: [*]u32, vaddr: u32, paddr: u32, flags: u32) void {
    if (!isAligned(vaddr, PAGE_SIZE)) @panic("Unaligned virtual address");
    if (!isAligned(paddr, PAGE_SIZE)) @panic("Unaligned physical address");

    const vpn1 = (vaddr >> sv32.VPN1_SHIFT) & sv32.VPN_MASK;
    var pte1 = PageTableEntry{ .raw = table1[vpn1] };

    if (!pte1.isValid()) {
        const pt_paddr = allocator.allocPages(1);
        pte1 = PageTableEntry.fromPhysical(pt_paddr, @intFromEnum(PageFlags.valid));
        table1[vpn1] = pte1.raw;
    }

    const vpn0 = (vaddr >> sv32.VPN0_SHIFT) & sv32.VPN_MASK;
    const table0: [*]u32 = @ptrFromInt(pte1.getPhysicalAddress());

    const pte0 = PageTableEntry.fromPhysical(paddr, flags | @intFromEnum(PageFlags.valid));
    table0[vpn0] = pte0.raw;
}

pub fn unmapPage(table1: [*]u32, vaddr: u32) void {
    if (!isAligned(vaddr, PAGE_SIZE)) @panic("Unaligned virtual address");

    const vpn1 = (vaddr >> sv32.VPN1_SHIFT) & sv32.VPN_MASK;
    const pte1 = PageTableEntry{ .raw = table1[vpn1] };

    if (!pte1.isValid()) @panic("Page not mapped");

    const vpn0 = (vaddr >> sv32.VPN0_SHIFT) & sv32.VPN_MASK;
    const table0: [*]u32 = @ptrFromInt(pte1.getPhysicalAddress());
    table0[vpn0] = 0;
}

fn isAligned(addr: u32, size: u32) bool {
    return (addr & (size - 1)) == 0;
}
