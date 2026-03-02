//! Kernel entry point — initializes subsystems and starts the scheduler.

const arch = @import("arch");
const console = @import("console");
const panic_lib = @import("panic");
const allocator = @import("allocator");
const layout = @import("layout");
const process = @import("process");
const virtio = @import("virtio");

// Pull in trap/yield/user_entry exports so they are linked into the kernel.
comptime {
    _ = @import("trap");
}

const user_bin = @embedFile("user.bin");

var virtio_blk_state: virtio.VirtioBlk = undefined;

extern const __bss: [*]u8;
extern const __bss_end: [*]u8;
extern const __free_ram: [*]u8;
extern const __free_ram_end: [*]u8;

export fn kernel_main() noreturn {
    const bss_len = @intFromPtr(__bss_end) - @intFromPtr(__bss);
    @memset(__bss[0..bss_len], 0);

    console.printf("\n[rk] BOOTING kernel...\n", .{});

    console.printf("[rk] setting trap vector...\n", .{});
    arch.csr.write("stvec", @intFromPtr(&arch.kernelEntry));

    console.printf("[rk] initializing allocator...\n", .{});
    const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
    const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });
    console.printf("[rk] __free_ram={x}, __free_ram_end={x}\n", .{ @intFromPtr(free_ram), @intFromPtr(free_ram_end) });
    allocator.init(@intFromPtr(free_ram));

    console.printf("[rk] initializing virtio-blk...\n", .{});
    virtio_blk_state = virtio.VirtioBlk.init() catch |err| {
        panic_lib.panic("VirtIO init failed: {}", .{err});
    };

    console.printf("[rk] initializing scheduler...\n", .{});
    process.initScheduler() catch |err| {
        panic_lib.panic("Failed to initialize scheduler: {}", .{err});
    };

    console.printf("[rk] creating user processes...\n", .{});
    _ = process.Process.create(layout.USER_BASE, user_bin) catch |err| {
        panic_lib.panic("Failed to create user process 1: {}", .{err});
    };
    _ = process.Process.create(layout.USER_BASE, user_bin) catch |err| {
        panic_lib.panic("Failed to create user process 2: {}", .{err});
    };

    console.printf("[rk] starting scheduler...\n", .{});
    process.yield();

    panic_lib.panic("unexpected return from yield", .{});
}
