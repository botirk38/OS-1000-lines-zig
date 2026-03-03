pub fn alignUp(addr: usize, alignment: usize) usize {
    return (addr + alignment - 1) & ~(alignment - 1);
}

pub fn alignDown(addr: usize, alignment: usize) usize {
    return addr & ~(alignment - 1);
}

pub fn isAligned(addr: usize, alignment: usize) bool {
    return (addr & (alignment - 1)) == 0;
}
