pub fn alignUp(addr: u32, alignment: u32) u32 {
    return (addr + alignment - 1) & ~(alignment - 1);
}

pub fn alignDown(addr: u32, alignment: u32) u32 {
    return addr & ~(alignment - 1);
}

pub fn isAligned(addr: u32, alignment: u32) bool {
    return (addr & (alignment - 1)) == 0;
}
