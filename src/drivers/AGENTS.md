# drivers — Agent Guidance

- VirtIO uses legacy interface (version 1) with a fixed MMIO address (`VIRTIO_BLK_PADDR = 0x10001000`).
- The console `printf` is a simple format engine; it supports `{}, {s}, {x}, {d}` but not all Zig format specifiers.
