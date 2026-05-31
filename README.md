# pico-os

A minimal operating system for RISC-V 32-bit, written in Zig.

## Demo

https://youtu.be/9htanzAm9qw

## What is this?

pico-os is a small educational OS inspired by "Operating System in 1,000 Lines". It demonstrates the basics of OS development: booting, memory management, process scheduling, and user-mode syscalls.

## Features

- Boots under QEMU (riscv32) with OpenSBI
- SV32 paging with two-level page tables
- Bump allocator for physical page allocation
- Round-robin cooperative process scheduling
- User mode with trap handling
- Console I/O via SBI
- VirtIO block device driver
- Tar-based filesystem (read/write)
- Interactive shell with file read/write commands

## Syscalls

| Syscall    | Number | Description                           |
|------------|--------|---------------------------------------|
| `write`    | 1      | Write to fd (1=stdout, 2=stderr)      |
| `read`     | 2      | Read from fd (0=stdin)                |
| `exit`     | 3      | Exit process with code                |
| `yield`    | 4      | Yield CPU to scheduler                |
| `getpid`   | 5      | Return process ID                     |
| `readfile` | 6      | Read file from disk image             |
| `writefile`| 7      | Write file to disk image              |

## Shell Commands

| Command     | Description                            |
|-------------|----------------------------------------|
| `hello`     | Print "Hello world from shell!"        |
| `exit`      | Exit the shell (panics kernel)         |
| `readfile`  | Read and print `hello.txt` from disk   |
| `writefile` | Write "Hello from shell!" to disk      |

## Requirements

- Zig 0.16.0+
- QEMU with riscv32 support
- LLVM tools (objcopy, objdump, nm)

## Quick Start

```bash
git clone https://github.com/botirk38/pico-os.git
cd pico-os

# Default build (ReleaseSmall)
zig build

# Run in QEMU
zig build run

# Debug build (maps to ReleaseSmall, Debug would hang without console)
zig build -Doptimize=ReleaseSafe

# Change log level
zig build -Dlog_level=debug

# Run
zig build run
```

## Other useful commands

```bash
zig fmt --check src/        # Check formatting
zig build                   # Build kernel and user binaries
zig build run               # Run in QEMU
```

## Project Structure

```
src/
├── abi/        # Syscall number definitions (shared ABI)
├── arch/       # RISC-V architecture specifics (CSR, paging, context switch)
├── drivers/    # SBI, console, VirtIO block device
├── fs/         # Tar-based filesystem
├── kernel/     # Entry point, trap handling, syscall dispatch, root context
├── lib/        # Logger, panic, math utilities
├── linker/     # Kernel and user binary linker scripts
├── mm/         # Memory layout, bump allocator
├── proc/       # Process structure and table
├── sched/      # Round-robin cooperative scheduler
└── user/       # User-space program (shell) and library (syscall stubs, I/O)
```

## Known Limitations

- Bump allocator cannot free pages; exited process memory leaks.
- Scheduling is cooperative (no timer interrupts).
- Filesystem: max 2 files, 1024 bytes per file, no directories.
- User pointer validation checks address range only; does not walk page tables.
- Debug builds hang because panic machinery runs before console is ready.

## License

MIT
