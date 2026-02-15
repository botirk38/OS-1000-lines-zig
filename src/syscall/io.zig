pub fn write(fd: u32, buf: u32, len: u32) i32 {
    _ = fd;
    _ = buf;
    _ = len;
    @panic("TODO: implement sys_write");
}

pub fn read(fd: u32, buf: u32, len: u32) i32 {
    _ = fd;
    _ = buf;
    _ = len;
    @panic("TODO: implement sys_read");
}
