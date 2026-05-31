# user — Agent Guidance

- User code is compiled as a separate executable and embedded as a binary blob in the kernel.
- The `start` function sets the stack pointer and jumps to `main` — no runtime init.
- Syscall stubs must preserve the `abi.Syscall` enum values for compatibility with the kernel dispatch table.
- I/O functions translate `\n` to `\r\n` for raw terminal mode.
