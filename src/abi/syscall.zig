pub const Syscall = enum(u32) {
    write = 1,
    read = 2,
    exit = 3,
    yield = 4,
    getpid = 5,
    readfile = 6,
    writefile = 7,
    _,
};
