# arch — RISC-V Architecture Layer

Architecture-specific implementations for RISC-V 32-bit: CSR access, SV32 paging, context switching, trap frame, and the boot entry point.

Key types:
- `Word` — u32 alias.
- `VAddr`, `PAddr` — typed virtual/physical addresses.
- `TrapFrame` — saved register state on trap entry.
- `Paging` — `map`, `unmap`, `Root` for page table operations.
- `Context` — `swap` and `activateAddressSpace` for process switching.
