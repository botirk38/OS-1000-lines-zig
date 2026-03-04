const sys = @import("syscall.zig");

pub fn putchar(c: u8) void {
    if (c == '\n') {
        _ = sys.write(1, "\r\n", 2);
    } else {
        _ = sys.write(1, @as([*]const u8, @ptrCast(&c)), 1);
    }
}

pub fn putstr(s: []const u8) void {
    // Translate \n -> \r\n for raw terminal mode.
    var start: usize = 0;
    for (s, 0..) |c, i| {
        if (c == '\n') {
            if (i > start) _ = sys.write(1, s[start..i].ptr, @intCast(i - start));
            _ = sys.write(1, "\r\n", 2);
            start = i + 1;
        }
    }
    if (start < s.len) _ = sys.write(1, s[start..].ptr, @intCast(s.len - start));
}

/// Returns the next byte from stdin, blocking until one is available.
/// Returns null on EOF (read returned <= 0).
pub fn getchar() ?u8 {
    var c: u8 = undefined;
    const n = sys.read(0, @as([*]u8, @ptrCast(&c)), 1);
    if (n <= 0) return null;
    return c;
}

/// Read a line from stdin into `buf`, echoing characters.
/// Returns the slice of `buf` containing the typed command (without newline),
/// or null on EOF or if the command was too long.
pub fn readline(buf: []u8) ?[]u8 {
    var i: usize = 0;
    while (true) {
        const ch = getchar();
        if (ch == null) {
            return null;
        }
        const c = ch.?;

        if (c == '\r' or c == '\n') {
            _ = sys.write(1, "\r\n", 2);
            return buf[0..i];
        }
        if (i >= buf.len - 1) {
            putstr("command line too long\n");
            return null;
        }
        buf[i] = c;
        i += 1;
        putchar(c); // echo
    }
}
