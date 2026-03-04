const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none,
    });

    // Bare-metal target: always optimise. Debug builds hang due to safety-check
    // panic machinery running before the console is ready. Use --release=safe or
    // --release=fast to override the default ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });
    const effective_optimize = if (optimize == .Debug) .ReleaseSmall else optimize;

    // Build-time log level. Controls which log calls are compiled in.
    // Usage: zig build -Dlog_level=debug
    const log_level = b.option(
        []const u8,
        "log_level",
        "Logging level: err, warn, info, debug (default: info)",
    ) orelse "info";

    // Inject log_level as a comptime-accessible build option.
    const build_opts = b.addOptions();
    build_opts.addOption([]const u8, "log_level", log_level);

    const arch_module = b.createModule(.{
        .root_source_file = b.path("src/arch/riscv32.zig"),
        .target = target,
        .optimize = effective_optimize,
    });

    const drivers_sbi_module = b.createModule(.{
        .root_source_file = b.path("src/drivers/sbi.zig"),
        .target = target,
        .optimize = effective_optimize,
    });

    const drivers_console_module = b.createModule(.{
        .root_source_file = b.path("src/drivers/console.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    drivers_console_module.addImport("sbi", drivers_sbi_module);

    // Logger depends only on console and the build options.
    const lib_logger_module = b.createModule(.{
        .root_source_file = b.path("src/lib/logger.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    lib_logger_module.addImport("console", drivers_console_module);
    lib_logger_module.addOptions("build_options", build_opts);

    const lib_panic_module = b.createModule(.{
        .root_source_file = b.path("src/lib/panic.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    lib_panic_module.addImport("console", drivers_console_module);
    lib_panic_module.addImport("sbi", drivers_sbi_module);
    lib_panic_module.addImport("logger", lib_logger_module);

    const mm_layout_module = b.createModule(.{
        .root_source_file = b.path("src/mm/layout.zig"),
        .target = target,
        .optimize = effective_optimize,
    });

    const mm_allocator_module = b.createModule(.{
        .root_source_file = b.path("src/mm/allocator.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    mm_allocator_module.addImport("layout", mm_layout_module);
    mm_allocator_module.addImport("logger", lib_logger_module);

    const lib_math_module = b.createModule(.{
        .root_source_file = b.path("src/lib/math.zig"),
        .target = target,
        .optimize = effective_optimize,
    });

    const drivers_virtio_module = b.createModule(.{
        .root_source_file = b.path("src/drivers/virtio_blk.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    drivers_virtio_module.addImport("logger", lib_logger_module);
    drivers_virtio_module.addImport("allocator", mm_allocator_module);
    drivers_virtio_module.addImport("layout", mm_layout_module);
    drivers_virtio_module.addImport("math", lib_math_module);

    const fs_module = b.createModule(.{
        .root_source_file = b.path("src/fs/fs.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    fs_module.addImport("allocator", mm_allocator_module);
    fs_module.addImport("virtio", drivers_virtio_module);
    fs_module.addImport("logger", lib_logger_module);
    fs_module.addImport("math", lib_math_module);

    const mm_paging_module = b.createModule(.{
        .root_source_file = b.path("src/mm/paging.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    mm_paging_module.addImport("allocator", mm_allocator_module);
    mm_paging_module.addImport("arch", arch_module);
    mm_paging_module.addImport("logger", lib_logger_module);

    const proc_process_module = b.createModule(.{
        .root_source_file = b.path("src/proc/process.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    proc_process_module.addImport("allocator", mm_allocator_module);
    proc_process_module.addImport("paging", mm_paging_module);
    proc_process_module.addImport("layout", mm_layout_module);
    proc_process_module.addImport("arch", arch_module);
    proc_process_module.addImport("virtio", drivers_virtio_module);
    proc_process_module.addImport("logger", lib_logger_module);

    const syscall_module = b.createModule(.{
        .root_source_file = b.path("src/syscall/syscall.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    syscall_module.addImport("arch", arch_module);
    syscall_module.addImport("sbi", drivers_sbi_module);
    syscall_module.addImport("logger", lib_logger_module);
    syscall_module.addImport("process", proc_process_module);
    syscall_module.addImport("fs", fs_module);

    const kernel_trap_module = b.createModule(.{
        .root_source_file = b.path("src/kernel/trap.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    kernel_trap_module.addImport("arch", arch_module);
    kernel_trap_module.addImport("panic", lib_panic_module);
    kernel_trap_module.addImport("layout", mm_layout_module);
    kernel_trap_module.addImport("syscall", syscall_module);
    kernel_trap_module.addImport("logger", lib_logger_module);

    const kernel_main_module = b.createModule(.{
        .root_source_file = b.path("src/kernel/main.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    kernel_main_module.addImport("arch", arch_module);
    kernel_main_module.addImport("logger", lib_logger_module);
    kernel_main_module.addImport("panic", lib_panic_module);
    kernel_main_module.addImport("allocator", mm_allocator_module);
    kernel_main_module.addImport("layout", mm_layout_module);
    kernel_main_module.addImport("process", proc_process_module);
    kernel_main_module.addImport("virtio", drivers_virtio_module);
    kernel_main_module.addImport("trap", kernel_trap_module);
    kernel_main_module.addImport("fs", fs_module);

    const exe = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = kernel_main_module,
    });
    exe.setLinkerScript(b.path("src/linker/kernel.ld"));
    exe.entry = .disabled;

    b.installArtifact(exe);

    const user_module = b.createModule(.{
        .root_source_file = b.path("src/user/main.zig"),
        .target = target,
        .optimize = effective_optimize,
    });
    user_module.addImport("syscall", syscall_module);

    const user = b.addExecutable(.{
        .name = "user.elf",
        .root_module = user_module,
    });
    user.entry = .disabled;
    user.setLinkerScript(b.path("src/linker/user.ld"));
    b.installArtifact(user);

    const elf2bin = b.addSystemCommand(&.{
        "llvm-objcopy",
        "--set-section-flags",
        ".bss=alloc,contents",
        "-O",
        "binary",
    });

    elf2bin.addArtifactArg(user);
    const bin_file_name = "user.bin";
    const bin = elf2bin.addOutputFileArg(bin_file_name);

    kernel_main_module.addAnonymousImport("user.bin", .{
        .root_source_file = bin,
    });

    exe.step.dependOn(&elf2bin.step);

    const run_cmd = b.addSystemCommand(&.{"qemu-system-riscv32"});
    run_cmd.addArgs(&.{ "-machine", "virt", "-bios", "default", "-nographic", "-serial", "mon:stdio", "--no-reboot", "-kernel" });

    run_cmd.addArtifactArg(exe);

    run_cmd.addArgs(&.{
        "-drive",  "id=drive0,file=disk.img,format=raw,if=none",
        "-device", "virtio-blk-device,drive=drive0,bus=virtio-mmio-bus.0",
    });

    const run_step = b.step("run", "Run QEMU");
    run_step.dependOn(&run_cmd.step);
}
