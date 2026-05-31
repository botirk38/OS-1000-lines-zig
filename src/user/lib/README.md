# user/lib — User-Space Library

Support library imported by the user shell.

- `syscall.zig` — Low-level syscall stubs (`write`, `read`, `exit`, `yield`, `getpid`, `readfile`, `writefile`).
- `io.zig` — Console I/O with newline translation and line editing.
