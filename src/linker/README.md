# linker — Linker Scripts

Linker scripts for kernel and user binaries.

- `kernel.ld` — Places kernel at `0x80200000` with 128KB stack and 64MB free RAM region.
- `user.ld` — Places user program at `0x1000000` with 64KB stack; asserts < `0x1800000`.
