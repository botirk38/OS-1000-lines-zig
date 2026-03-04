const sbi = @import("sbi");
const process = @import("process");

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

    // Block until at least one character is available, yielding between attempts.
    // Matches C reference SYS_GETCHAR: loops getchar() + yield() until ch >= 0.
    const ptr: [*]u8 = @ptrFromInt(buf);
    const ch = while (true) {
        const c = sbi.getChar();
        if (c >= 0) break c;
        process.yield();
    };

    ptr[0] = @intCast(ch);
    return 1;
}
