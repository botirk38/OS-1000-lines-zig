# arch — Agent Guidance

- RISC-V 32-bit arch code lives under `src/arch/rv32/` as separate domain files:
  - `arch.zig` — public facade re-exporting struct-based namespaces.
  - `csr.zig` — CSR read/write wrappers (internal, not exported).
  - `trap.zig` — trap frame, trap types, `kernelEntry` naked asm, `boot` entry.
  - `context.zig` — `switch_context` assembly for cooperative context switching.
  - `paging.zig` — SV32 page table map/unmap, `VAddr`/`PAddr` types.
  - `sbi.zig` — SBI ecall wrapper (console I/O, shutdown).
- The public API is entirely struct-based: `arch.Paging`, `arch.Trap`, `arch.Syscall`, `arch.Context`, `arch.Sbi`.
- External code references types as `arch.Paging.VAddr`, `arch.Paging.Root`, `arch.Trap.Frame`, etc.
- Every future architecture implements the same struct namespaces under its own `arch.zig`.
- Paging map/unmap allocates intermediate page tables via `allocator.allocPages`.
- Adding a new architecture: create a new directory under `src/arch/`, implement the same struct API, and add an `arch_path` entry in `build.zig`.
