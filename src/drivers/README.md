# drivers — Hardware Drivers

Two hardware interface layers:

- `console.zig` — Formatted `printf` output using SBI `putChar`.
- `virtio_blk.zig` — VirtIO block device driver using legacy MMIO interface with descriptor rings.

Platform console I/O lives in `src/arch/rv32/` as it is architecture-specific.
