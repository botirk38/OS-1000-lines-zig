# mm — Memory Management

Memory layout constants and a simple bump allocator for physical page allocation.

- `layout.zig` — `PAGE_SIZE` (4096), `USER_BASE` (0x1000000), `STACK_SIZE` (8192), `KERNEL_BASE` (0x80200000).
- `allocator.zig` — Bump allocator (`allocPages`); no `free` support.
