# user/lib — Agent Guidance

- The raw syscall function uses inline asm with `ecall`; register arguments follow RISC-V calling convention (a7 = number, a0–a2 = args).
- I/O functions depend on syscall stubs; adding a new syscall requires a stub here and a handler in `kernel/syscall.zig`.
- These modules are compiled as part of the user-space binary (`.os_tag = .freestanding`).
