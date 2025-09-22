//! Memory management - page table implementation
//! Provides virtual memory management for RISC-V SV32

const std = @import("std");
const common = @import("../common.zig");
const allocator = @import("allocator.zig");

const PAGE_SIZE = allocator.PAGE_SIZE;
const PageFlags = allocator.PageFlags;

/// Page table entry structure
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

/// Map a virtual page to a physical page
pub fn mapPage(table1: [*]u32, vaddr: u32, paddr: u32, flags: u32) !void {
    if (!isAligned(vaddr, PAGE_SIZE)) return error.UnalignedVirtualAddress;
    if (!isAligned(paddr, PAGE_SIZE)) return error.UnalignedPhysicalAddress;

    const vpn1 = (vaddr >> 22) & 0x3FF;
    var pte1 = PageTableEntry{ .raw = table1[vpn1] };

    if (!pte1.isValid()) {
        const pt_pages = try allocator.allocPages(1);
        pte1 = PageTableEntry.fromPhysical(@intFromPtr(pt_pages.ptr), @intFromEnum(PageFlags.valid));
        table1[vpn1] = pte1.raw;
    }

    const vpn0 = (vaddr >> 12) & 0x3FF;
    const table0: [*]u32 = @ptrFromInt(pte1.getPhysicalAddress());
    const pte0 = PageTableEntry.fromPhysical(paddr, flags | @intFromEnum(PageFlags.valid));
    table0[vpn0] = pte0.raw;
}

/// Unmap a virtual page
pub fn unmapPage(table1: [*]u32, vaddr: u32) !void {
    if (!isAligned(vaddr, PAGE_SIZE)) return error.UnalignedVirtualAddress;

    const vpn1 = (vaddr >> 22) & 0x3FF;
    const pte1 = PageTableEntry{ .raw = table1[vpn1] };

    if (!pte1.isValid()) return error.PageNotMapped;

    const vpn0 = (vaddr >> 12) & 0x3FF;
    const table0: [*]u32 = @ptrFromInt(pte1.getPhysicalAddress());
    table0[vpn0] = 0;
}

/// Check if an address is aligned to the given size
fn isAligned(addr: u32, size: u32) bool {
    return (addr & (size - 1)) == 0;
}