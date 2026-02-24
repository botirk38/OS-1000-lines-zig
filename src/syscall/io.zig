const sbi = @import("sbi");

pub fn write(fd: u32, buf: u32, len: u32) i32 {
    if (fd != 1 and fd != 2) return -1;

    const ptr: [*]const u8 = @ptrFromInt(buf);
    var i: u32 = 0;
    while (i < len) : (i += 1) {
        sbi.putChar(ptr[i]);
    }
    return @intCast(i);
}

pub fn read(fd: u32, buf: u32, len: u32) i32 {
    if (fd != 0) return -1;
    if (len == 0) return 0;

    const ptr: [*]u8 = @ptrFromInt(buf);
    var copied: u32 = 0;
    while (copied < len) : (copied += 1) {
        const ch = sbi.getChar();
        if (ch < 0) break;
        ptr[copied] = @intCast(ch);
    }

    return @intCast(copied);
}
