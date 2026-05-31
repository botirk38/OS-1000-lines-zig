const allocator = @import("allocator");
const log = @import("logger");

const Word = @import("arch.zig").Word;

const VPN_BITS: u5 = 10;
const VPN_MASK: Word = (1 << VPN_BITS) - 1;
const VPN1_SHIFT: u5 = 22;
const VPN0_SHIFT: u5 = 12;
const PTE_PPN_SHIFT: u5 = 10;
const PTE_PPN_BITS: u5 = 22;
const PTE_PPN_MASK: Word = (1 << PTE_PPN_BITS) - 1;
const PTE_FLAGS_MASK: Word = VPN_MASK;

const SATP_SV32: Word = 1 << 31;

const PageFlags = enum(u32) {
    valid = 1 << 0,
    read = 1 << 1,
    write = 1 << 2,
    exec = 1 << 3,
    user = 1 << 4,
};

const PageTableEntry = struct {
    raw: Word,

    fn fromPhysical(paddr: Word, flags: Word) PageTableEntry {
        return .{ .raw = ((paddr / 4096) << PTE_PPN_SHIFT) | (flags & PTE_FLAGS_MASK) };
    }

    fn isValid(self: PageTableEntry) bool {
        return (self.raw & @intFromEnum(PageFlags.valid)) != 0;
    }

    fn getPhysicalAddress(self: PageTableEntry) Word {
        return ((self.raw >> PTE_PPN_SHIFT) & PTE_PPN_MASK) * 4096;
    }
};

fn isAligned(addr: Word, size: Word) bool {
    return (addr & (size - 1)) == 0;
}

pub const Paging = struct {
    pub const VAddr = enum(Word) { _ };
    pub const PAddr = enum(Word) { _ };

    pub const Error = error{
        UnalignedAddress,
        NotMapped,
    };

    pub const Root = struct {
        ptr: [*]Word,
    };

    pub const Flag = enum {
        read,
        write,
        exec,
        user,
    };

    pub fn rootFromPtr(ptr: [*]Word) Root {
        return .{ .ptr = ptr };
    }

    pub fn map(root: Root, vaddr: VAddr, paddr: PAddr, flags: []const Flag) (Error || allocator.AllocError)!void {
        const raw_vaddr = @intFromEnum(vaddr);
        const raw_paddr = @intFromEnum(paddr);

        if (!isAligned(raw_vaddr, allocator.PAGE_SIZE)) return error.UnalignedAddress;
        if (!isAligned(raw_paddr, allocator.PAGE_SIZE)) return error.UnalignedAddress;

        const vpn1 = (raw_vaddr >> VPN1_SHIFT) & VPN_MASK;
        var pte1 = PageTableEntry{ .raw = root.ptr[vpn1] };

        if (!pte1.isValid()) {
            const pt_paddr = try allocator.allocPages(1);
            pte1 = PageTableEntry.fromPhysical(pt_paddr, @intFromEnum(PageFlags.valid));
            root.ptr[vpn1] = pte1.raw;
        }

        const vpn0 = (raw_vaddr >> VPN0_SHIFT) & VPN_MASK;
        const table0: [*]Word = @ptrFromInt(pte1.getPhysicalAddress());

        var raw_flags: Word = @intFromEnum(PageFlags.valid);
        for (flags) |f| {
            raw_flags |= switch (f) {
                .read => @intFromEnum(PageFlags.read),
                .write => @intFromEnum(PageFlags.write),
                .exec => @intFromEnum(PageFlags.exec),
                .user => @intFromEnum(PageFlags.user),
            };
        }

        const pte0 = PageTableEntry.fromPhysical(raw_paddr, raw_flags);
        table0[vpn0] = pte0.raw;

        log.debug("mm", "map vaddr={x} -> paddr={x}", .{ raw_vaddr, raw_paddr });
    }

    pub fn unmap(root: Root, vaddr: VAddr) Error!void {
        const raw_vaddr = @intFromEnum(vaddr);

        if (!isAligned(raw_vaddr, allocator.PAGE_SIZE)) return error.UnalignedAddress;

        const vpn1 = (raw_vaddr >> VPN1_SHIFT) & VPN_MASK;
        const pte1 = PageTableEntry{ .raw = root.ptr[vpn1] };

        if (!pte1.isValid()) return error.NotMapped;

        const vpn0 = (raw_vaddr >> VPN0_SHIFT) & VPN_MASK;
        const table0: [*]Word = @ptrFromInt(pte1.getPhysicalAddress());
        table0[vpn0] = 0;
    }

    pub fn satpValue(root: Root) Word {
        return SATP_SV32 | (@intFromPtr(root.ptr) / 4096);
    }
};
