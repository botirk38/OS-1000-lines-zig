//! Kernel entry point — initializes subsystems and starts the scheduler.

const arch = @import("arch");
const log = @import("logger");
const panic_lib = @import("panic");
const allocator = @import("allocator");
const layout = @import("layout");
const process = @import("process");
const virtio = @import("virtio");
const fs = @import("fs");

// Pull in trap/yield/user_entry exports so they are linked into the kernel.
comptime {
    _ = @import("trap");
}

const user_bin = @embedFile("user.bin");

var virtio_blk_state: virtio.VirtioBlk = undefined;

extern const __bss: [*]u8;
extern const __bss_end: [*]u8;
extern const __free_ram: [*]u8;

export fn kernel_main() noreturn {
    const bss_len = @intFromPtr(__bss_end) - @intFromPtr(__bss);
    @memset(__bss[0..bss_len], 0);

    arch.csr.write("stvec", @intFromPtr(&arch.kernelEntry));

    const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
    allocator.init(@intFromPtr(free_ram));

    virtio_blk_state = virtio.VirtioBlk.init() catch |err| {
        panic_lib.panic("VirtIO init failed: {}", .{err});
    };
    log.info("kernel", "VirtIO initialized", .{});

    fs.init(&virtio_blk_state);
    log.info("kernel", "filesystem initialized", .{});

    // Initialize the process table and scheduler
    process.init();
    log.info("kernel", "scheduler initialized", .{});

    // Create idle process (slot 0)
    process.idle_proc = process.Process.create(null);
    process.idle_proc.?.pid = 0; // Override: idle has pid=0
    process.current_proc = process.idle_proc;
    log.info("kernel", "idle process created", .{});

    // Create user process
    _ = process.Process.create(user_bin);
    log.info("kernel", "user process created", .{});

    // Yield to the scheduler; if we ever return here, all processes have exited
    log.info("kernel", "starting scheduler", .{});
    process.yield();

    // Should never be reached unless the idle process is scheduled back,
    // which means all user processes have exited. Panic to signal this error.
    @panic("switched to idle process");
}
