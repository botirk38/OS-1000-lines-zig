# linker — Agent Guidance

- Kernel stack is embedded in the kernel image (`.bss` + `128KB`).
- Free RAM starts after the stack at a 4KB-aligned boundary.
- The user linker assert enforces the process address space limit used by `validateUserPtr`.
- Changing memory layout requires updating `layout.zig` and both linker scripts consistently.
