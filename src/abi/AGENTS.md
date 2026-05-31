# abi — Agent Guidance

- The enum is non-exhaustive (`_`) to allow future extension without breaking existing switch statements.
- Both `kernel/syscall.zig` and `user/lib/syscall.zig` import this module by name `abi`.
- Adding a syscall: add a variant here, a handler in `kernel/syscall.zig`, and a stub in `user/lib/syscall.zig`.
