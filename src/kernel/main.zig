const std = @import("std");
const arch = @import("arch");
const fmt = @import("fmt");
const panic_lib = @import("panic");
const allocator = @import("allocator");
const layout = @import("layout");
const process = @import("process");
const scheduler = @import("scheduler");
const syscall = @import("syscall");

const user_bin = @embedFile("user.bin");

extern const __bss: [*]u8;
extern const __bss_end: [*]u8;
extern const __free_ram: [*]u8;
extern const __free_ram_end: [*]u8;

export fn kernel_main() noreturn {
    const bss_len = @intFromPtr(__bss_end) - @intFromPtr(__bss);
    @memset(__bss[0..bss_len], 0);

    fmt.printf("\n[rk] booting kernel...\n", .{});

    fmt.printf("[rk] setting trap vector...\n", .{});
    arch.csr.write("stvec", @intFromPtr(&arch.kernelEntry));

    fmt.printf("[rk] initializing allocator...\n", .{});
    const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
    const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });
    fmt.printf("[rk] __free_ram={x}, __free_ram_end={x}\n", .{ @intFromPtr(free_ram), @intFromPtr(free_ram_end) });
    allocator.init(@intFromPtr(free_ram));

    fmt.printf("[rk] initializing scheduler...\n", .{});
    scheduler.Scheduler.init() catch |err| {
        panic_lib.panic("Failed to initialize scheduler: {}", .{err});
    };

    _ = process.Process.create(layout.USER_BASE, user_bin) catch |err| {
        panic_lib.panic("Failed to create user process: {}", .{err});
    };

    scheduler.Scheduler.yield();

    panic_lib.panic("unexpected return from yield", .{});
}

export fn user_entry() callconv(.naked) void {
    asm volatile (
        \\csrw sepc, %[sepc]
        \\csrw sstatus, %[sstatus]
        \\sret
        :
        : [sepc] "r" (layout.USER_BASE),
          [sstatus] "r" (arch.SSTATUS_SPIE),
    );
}

export fn yield() void {
    scheduler.Scheduler.yield();
}

export fn handleTrap(frame: *arch.TrapFrame) callconv(.c) void {
    const scause = arch.csr.read("scause");
    const stval = arch.csr.read("stval");
    const sepc = arch.csr.read("sepc");

    if (arch.isException(scause, arch.ECALL_FROM_U)) {
        syscall.dispatch(frame);
        arch.csr.write("sepc", sepc + 4);
        return;
    }

    panic_lib.panic("trap: scause={x}, stval={x}, sepc={x}, ra={x}, sp={x}", .{
        scause,
        stval,
        sepc,
        frame.ra,
        frame.sp,
    });
}
