# user — User-Space Program

The user-space shell and supporting library.

- `main.zig` — Interactive shell with commands: `hello`, `exit`, `readfile`, `writefile`.
- `lib/syscall.zig` — Syscall stubs using `ecall` instruction.
- `lib/io.zig` — I/O helpers (putchar, putstr, getchar, readline) with `\n` → `\r\n` translation.
