# kernel — Kernel Entry, Traps, Syscalls

The kernel module contains the core OS logic: boot entry, trap handling, syscall dispatch, and the root kernel context that owns the process table and scheduler.

Key files:
- `main.zig` — Boot entry (`kernel_main`), initializes subsystems, creates idle and user processes, starts scheduler.
- `trap.zig` — Trap handler (`handleTrap`), `user_entry` assembly stub for `SRET` into user mode.
- `syscall.zig` — Syscall dispatch table with user pointer validation.
- `context.zig` — `Context` struct: single root context owning process table and scheduler.
