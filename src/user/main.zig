const sys = @import("lib/syscall.zig");

export fn start() linksection(".text.start") callconv(.naked) void {
    asm volatile (
        \\la sp, __stack_top
        \\call main
    );
}

fn putchar(c: u8) void {
    _ = sys.write(1, @as([*]const u8, @ptrCast(&c)), 1);
}

fn putstr(s: []const u8) void {
    _ = sys.write(1, s.ptr, @intCast(s.len));
}

fn putdec(val: u32) void {
    if (val == 0) {
        putchar('0');
        return;
    }
    var buf: [10]u8 = undefined;
    var pos: usize = 0;
    var v = val;
    while (v > 0) : (v /= 10) {
        buf[pos] = @as(u8, @intCast(v % 10)) + '0';
        pos += 1;
    }
    while (pos > 0) {
        pos -= 1;
        putchar(buf[pos]);
    }
}

export fn main() noreturn {
    const pid = sys.getpid();
    var tick: u32 = 0;
    while (true) {
        tick +%= 1;
        putstr("[user] pid=");
        putdec(pid);
        putstr(" tick=");
        putdec(tick);
        putchar('\n');
        sys.yield();
    }
}
