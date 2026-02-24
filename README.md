# OS-1000-lines-zig

A small educational operating system for RISC-V 32-bit, written in Zig.

This project follows the spirit of the "Operating System in 1,000 Lines" tutorial, but uses idiomatic Zig modules and build tooling.

## Status

Working now:
- Boots under QEMU (`riscv32`)
- Sets up SV32 paging and basic memory allocator
- Creates and schedules processes (round-robin, cooperative)
- Switches to user mode with privilege separation
- Handles user `ecall` and dispatches basic syscalls
- Basic syscalls implemented: `write`, `read`, `yield`, `exit`

Not implemented yet:
- Timer/preemptive scheduling
- Block device driver (VirtIO)
- Filesystem
- Shell/userland utilities

See `ROADMAP.md` for longer-term milestones.

## Requirements

- Zig `0.15.2` (or compatible)
- QEMU with `qemu-system-riscv32`
- LLVM tools (`llvm-objcopy`, `llvm-objdump`)

### macOS (Homebrew)

```bash
brew install zig qemu llvm
```

If `llvm-objcopy` is not found:

```bash
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
```

## Quick Start

```bash
git clone https://github.com/botirk38/OS-1000-lines-zig.git
cd OS-1000-lines-zig

zig build
zig build run
```

## Common Commands

```bash
# format check
zig fmt --check src/

# build artifacts
zig build

# run in QEMU
zig build run

# inspect produced kernel
llvm-objdump -h zig-out/bin/kernel.elf
```

## Project Layout

```text
src/
  arch/      # RISC-V architecture support, trap entry, context switch
  drivers/   # SBI and console
  kernel/    # kernel entry and trap handler
  lib/       # formatting, panic, helpers
  mm/        # allocator, paging, memory layout
  proc/      # process and scheduler
  syscall/   # syscall ids + dispatcher + implementations
  user/      # user program and user syscall wrappers
```

## Notes on Syscalls

- User side wrappers are in `src/user/lib/syscall.zig`
- Kernel dispatch is in `src/syscall/syscall.zig`
- Trap handling path is in `src/kernel/main.zig` (`scause` checks + `sepc += 4` after `ecall`)

## Troubleshooting

- `llvm-objcopy: FileNotFound`
  - install LLVM and make sure it is on `PATH`
- `qemu-system-riscv32: command not found`
  - install QEMU and ensure `/opt/homebrew/bin` (macOS) is on `PATH`

## License

MIT
