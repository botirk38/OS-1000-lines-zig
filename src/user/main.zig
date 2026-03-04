const std = @import("std");
const sys = @import("lib/syscall.zig");
const io = @import("lib/io.zig");

export fn start() linksection(".text.start") callconv(.naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j main
        :
        : [stack_top] "r" (@extern([*]u8, .{ .name = "__stack_top" })),
    );
}

export fn main() noreturn {
    io.putstr("user: main() started\n");

    while (true) {
        io.putstr("> ");

        var cmdline: [128]u8 = undefined;
        const cmd = io.readline(&cmdline) orelse {
            continue;
        };

        if (std.mem.eql(u8, cmd, "hello")) {
            io.putstr("Hello world from shell!\n");
        } else if (std.mem.eql(u8, cmd, "exit")) {
            sys.exit(0);
        } else if (std.mem.eql(u8, cmd, "readfile")) {
            var buf: [128]u8 = undefined;
            const len = sys.readfile("hello.txt", &buf, buf.len);
            if (len < 0) {
                io.putstr("readfile: file not found\n");
            } else {
                io.putstr(buf[0..@intCast(len)]);
                io.putchar('\n');
            }
        } else if (std.mem.eql(u8, cmd, "writefile")) {
            const content = "Hello from shell!\n";
            const len = sys.writefile("hello.txt", content.ptr, content.len);
            if (len < 0) {
                io.putstr("writefile: error\n");
            }
        } else if (cmd.len > 0) {
            io.putstr("unknown command: ");
            io.putstr(cmd);
            io.putchar('\n');
        }
    }
}
