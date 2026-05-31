# drivers — Hardware Drivers

Two hardware interface layers:

- `console.zig` — Formatted `printf` output using SBI `putChar`.
- `virtio_blk.zig` — VirtIO block device driver using legacy MMIO interface with descriptor rings.

SBI calls live in `src/arch/rv32/sbi.zig` as they are RISC-V–specific.
