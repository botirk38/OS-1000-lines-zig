# OS-1000-lines-zig

A small educational OS for RISC-V 32-bit, written in Zig.

Inspired by "Operating System in 1,000 Lines", with idiomatic Zig modules and build tooling.

## Status

Implemented:
- Boots under QEMU (`riscv32`)
- SV32 paging and basic memory allocator
- Creates and schedules processes (round-robin, cooperative)
- User mode + trap handling for `ecall`
- Syscalls: `write`, `read`, `yield`, `exit`

Next:
- Timer/preemptive scheduling
- VirtIO block driver
- Filesystem
- Shell/user utilities

See `ROADMAP.md` for milestones.

## Setup

```bash
brew install zig qemu llvm
```

Requirements: Zig `0.15.2+`, `qemu-system-riscv32`, `llvm-objcopy`.

## Quick Start

```bash
git clone https://github.com/botirk38/OS-1000-lines-zig.git
cd OS-1000-lines-zig

zig build
zig build run
```

Useful commands:
- `zig fmt --check src/`
- `zig build`
- `zig build run`

## License

MIT
