const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kernel.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .riscv32, .os_tag = .freestanding, .abi = .none }),
            .optimize = .ReleaseSmall,
        }),
    });
    exe.setLinkerScript(b.path("src/kernel.ld"));

    exe.entry = .disabled;

    b.installArtifact(exe);

    const user = b.addExecutable(.{
        .name = "user.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/user.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .riscv32,
                .os_tag = .freestanding,
                .abi = .none,
            }),
            .optimize = .ReleaseSmall,
        }),
    });

    user.entry = .disabled;
    user.setLinkerScript(b.path("src/user.ld"));
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

    exe.root_module.addAnonymousImport("user.bin", .{
        .root_source_file = bin,
    });

    exe.step.dependOn(&elf2bin.step);

    const run_cmd = b.addSystemCommand(&.{"qemu-system-riscv32"});
    run_cmd.addArgs(&.{ "-machine", "virt", "-bios", "default", "-serial", "mon:stdio", "-monitor", "telnet:127.0.0.1:55556,server,nowait", "--no-reboot", "-nographic", "-kernel" });

    run_cmd.addArtifactArg(exe);

    const run_step = b.step("run", "Run QEMU");
    run_step.dependOn(&run_cmd.step);
}
