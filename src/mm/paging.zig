//! Memory management - page table implementation
//! Provides virtual memory management for RISC-V SV32

const std = @import("std");
const fmt = @import("fmt");
const allocator = @import("allocator");

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
pub fn mapPage(table1: [*]u32, vaddr: u32, paddr: u32, flags: u32) void {
    fmt.printf("[paging] mapPage: vaddr={x}, paddr={x}, flags={x}\n", .{ vaddr, paddr, flags });

    if (!isAligned(vaddr, PAGE_SIZE)) @panic("Unaligned virtual address");
    if (!isAligned(paddr, PAGE_SIZE)) @panic("Unaligned physical address");

    const vpn1 = (vaddr >> 22) & 0x3FF;
    fmt.printf("[paging] mapPage: vpn1={x}\n", .{vpn1});

    var pte1 = PageTableEntry{ .raw = table1[vpn1] };
    fmt.printf("[paging] mapPage: pte1.raw={x}, isValid={}\n", .{ pte1.raw, pte1.isValid() });

    if (!pte1.isValid()) {
        fmt.printf("[paging] mapPage: need to allocate second-level page table\n", .{});
        const pt_paddr = allocator.allocPages(1);
        fmt.printf("[paging] mapPage: allocated second-level at paddr={x}\n", .{pt_paddr});

        pte1 = PageTableEntry.fromPhysical(pt_paddr, @intFromEnum(PageFlags.valid));
        fmt.printf("[paging] mapPage: created pte1 with raw={x}\n", .{pte1.raw});

        table1[vpn1] = pte1.raw;
        fmt.printf("[paging] mapPage: stored pte1 in table1[{}]\n", .{vpn1});
    }

    const vpn0 = (vaddr >> 12) & 0x3FF;
    fmt.printf("[paging] mapPage: vpn0={x}\n", .{vpn0});

    const table0: [*]u32 = @ptrFromInt(pte1.getPhysicalAddress());
    fmt.printf("[paging] mapPage: table0 pointer={x}\n", .{@intFromPtr(table0)});

    const pte0 = PageTableEntry.fromPhysical(paddr, flags | @intFromEnum(PageFlags.valid));
    fmt.printf("[paging] mapPage: created pte0 with raw={x}\n", .{pte0.raw});

    table0[vpn0] = pte0.raw;
    fmt.printf("[paging] mapPage: stored pte0 in table0[{}], mapping complete\n", .{vpn0});
}

/// Unmap a virtual page
pub fn unmapPage(table1: [*]u32, vaddr: u32) void {
    if (!isAligned(vaddr, PAGE_SIZE)) @panic("Unaligned virtual address");

    const vpn1 = (vaddr >> 22) & 0x3FF;
    const pte1 = PageTableEntry{ .raw = table1[vpn1] };

    if (!pte1.isValid()) @panic("Page not mapped");

    const vpn0 = (vaddr >> 12) & 0x3FF;
    const table0: [*]u32 = @ptrFromInt(pte1.getPhysicalAddress());
    table0[vpn0] = 0;
}

/// Check if an address is aligned to the given size
fn isAligned(addr: u32, size: u32) bool {
    return (addr & (size - 1)) == 0;
}
