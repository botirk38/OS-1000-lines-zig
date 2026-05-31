# drivers — Hardware Drivers

Three hardware interface layers:

- `sbi.zig` — SBI (Supervisor Binary Interface) calls for console I/O and system reset.
- `console.zig` — Formatted `printf` output using SBI `putChar`.
- `virtio_blk.zig` — VirtIO block device driver using legacy MMIO interface with descriptor rings.
