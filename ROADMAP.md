# Roadmap

## Current Status

pico-os boots under QEMU riscv32 with SV32 paging, cooperative scheduling, user-mode syscalls, VirtIO block I/O, and a small tar-backed filesystem with a shell.

## Short-Term Priorities

- [ ] **CI reliability** — Fail CI on QEMU boot failure (QEMU test now has proper args and output check).
- [ ] **User pointer safety** — Range-check all user-provided addresses in syscall handlers.
- [ ] **Filesystem error propagation** — `fs.init` and `fs.flush` return errors properly rather than silently swallowing I/O failures.

## Medium-Term Improvements

- [ ] **Preemptive scheduling** — Add timer interrupt support for preemptive context switching.
- [ ] **Better memory allocator** — Replace the bump allocator with a buddy or slab allocator that supports `free()`.
- [ ] **Process cleanup** — Reclaim page-table and user-image pages when a process exits (blocked on allocator with free).
- [ ] **Filesystem hardening** — Tar checksum computation in `flush`, bounds-checked reads, more robust error handling.
- [ ] **Multi-process** — Load and run multiple user programs concurrently.
- [ ] **Signal handling** — Deliver signals (SIGKILL, SIGTERM) to user processes.

## Long-Term Goals

- [ ] **Multi-scheduler support** — Pluggable scheduling policies (FIFO, priority, etc.).
- [ ] **ELF loader** — Load ELF binaries instead of flat binary images.
- [ ] **SMP** — Boot secondary harts and distribute processes.
- [ ] **Network driver** — VirtIO-net device support.
- [ ] **Device tree parsing** — Discover hardware instead of hard-coded addresses.
- [ ] **Filesystem write-back cache** — Avoid writing every sector on every flush.
- [ ] **RISC-V 64-bit support** — Build option for RV64 with Sv39 paging.

## Known Limitations

- Bump allocator: no free; process memory is never reclaimed.
- No timer interrupts; scheduling is purely cooperative.
- Filesystem: max 2 files, 1024-byte data per file, no directories.
- User pointer validation checks address range only, not page-table permissions.
- CI QEMU test runs on Ubuntu only (macOS job builds only).

