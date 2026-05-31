# arch — Architecture Abstraction Layer

The `arch` module provides an architecture-independent interface for the kernel.
All platform-specific implementations live in subdirectories (e.g. `rv32/`).

The public API is struct-based:

- `arch.Paging` — page table operations, address types
- `arch.Trap` — trap handling, register frame, exception/interrupt types
- `arch.Syscall` — syscall argument accessors over a trap frame
- `arch.Context` — context switching and address space activation
- `arch.Console` — platform console I/O (putchar, getchar, shutdown)

Kernel code imports via `@import("arch")` and never imports implementation files directly.
