# pico-os

A minimal operating system for RISC-V 32-bit, written in Zig.

## What is this?

pico-os is a small educational OS inspired by "Operating System in 1,000 Lines". It demonstrates the basics of OS development: booting, memory management, process scheduling, and user-mode syscalls.

## Features

- Boots under QEMU (riscv32)
- SV32 paging with a basic memory allocator
- Round-robin cooperative process scheduling
- User mode with trap handling
- Syscalls: write, read, yield, exit

## Requirements

- Zig 0.15.2+
- QEMU with riscv32 support
- LLVM tools (objcopy, objdump, nm)

## Quick Start

```bash
git clone https://github.com/botirk38/pico-os.git
cd pico-os

zig build
zig build run
```

## Other useful commands

```bash
zig fmt --check src/   # Check formatting
zig build              # Build kernel and user binaries
zig build run          # Run in QEMU
```

## License

MIT
