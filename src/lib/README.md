# lib — Kernel Utility Library

Shared utilities used across the kernel:

- `logger.zig` — Compile-time-filtered logging (err/warn/info/debug levels controlled by `-Dlog_level`).
- `panic.zig` — Kernel panic handler.
- `math.zig` — Math utilities (`alignUp`, `alignDown`, `min`, `max`).
