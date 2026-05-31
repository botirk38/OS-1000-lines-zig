# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project Scope

- This is a freestanding RISC-V 32-bit OS project in Zig.
- The build is defined in `build.zig`.
- The main outputs are:
  - `kernel.elf` (kernel image)
  - `user.elf` and embedded `user.bin` (user image)

## Environment Prerequisites

- Zig (CI uses `0.16.0`; project targets `0.16.0+`)
- QEMU with `qemu-system-riscv32`
- LLVM tools:
  - `llvm-objcopy`
  - `llvm-objdump`
  - `llvm-nm`

## Canonical Commands

Use these commands before finalizing changes:

- Format check (CI-aligned): `zig fmt --check src/`
- Build: `zig build`
- Run in QEMU: `zig build run`

Useful local checks:

- Zig version: `zig version`
- QEMU version: `qemu-system-riscv32 --version`

## Codebase Map

- `src/kernel` - kernel entry, trap handling, syscall dispatch, root kernel context
- `src/arch` - RISC-V architecture specifics (`rv32/` subdirectory with struct-based namespaces: `arch.Paging`, `arch.Trap`, `arch.Context`, `arch.Syscall`, `arch.Console`)
- `src/mm` - memory layout constants, bump allocator
- `src/proc` - process structures, process table
- `src/sched` - round-robin cooperative scheduler
- `src/abi` - syscall number enum (shared ABI between kernel and user)
- `src/fs` - tar-based filesystem using VirtIO block device
- `src/drivers` - console (printf), VirtIO block driver (platform I/O lives in `src/arch/rv32/`)
- `src/lib` - compile-time-filtered logger, panic, math utilities
- `src/linker` - linker scripts for kernel and user binaries
- `src/user` - user-space shell program and library (syscall stubs, I/O helpers)

## Editing Rules For Agents

- Keep changes minimal and scoped to the task.
- Preserve freestanding assumptions (`.os_tag = .freestanding`, no host runtime dependencies).
- Preserve RISC-V 32-bit targeting and existing linker/build flow unless explicitly requested.
- Do not introduce host-only libraries or OS-specific APIs into kernel/user code.
- Prefer clear, explicit error handling; avoid hidden control flow.
- Always validate user-provided pointers before dereferencing in syscall handlers.
- Propagate I/O errors upward rather than silently swallowing them.
- If behavior or workflow changes, update relevant docs (`README.md`, `ROADMAP.md`, and this file when needed).

## Validation Checklist

Before handing off:

1. Run `zig fmt --check src/`.
2. Run `zig build`.
3. If runtime-related changes were made, run `zig build run` (or equivalent QEMU smoke boot check).

If a check cannot be run, state why and provide the exact command for maintainers to run.

## Commit and PR Guidance

- Explain why low-level changes are needed, especially around traps, paging, process state, and context switching.
- Call out architectural impact (memory layout, privilege transitions, syscall behavior).
- Include concise verification notes (which commands were run and outcomes).
- Note known limitations, follow-ups, or risks when relevant.
