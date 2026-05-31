# rv32 — Agent Guidance

- RISC-V 32-bit arch code lives under `src/arch/rv32/`:
  - `arch.zig` — public facade re-exporting struct-based namespaces
  - `console.zig` — architecture-neutral `Console` API backed by SBI
  - `sbi.zig` — raw RISC-V SBI ecalls (private, consumed only by `console.zig`)
  - `csr.zig` — CSR read/write wrappers (private)
  - `trap.zig` — trap frame, trap types, `kernelEntry` naked asm, `boot` entry
  - `context.zig` — `switch_context` assembly for cooperative context switching
  - `paging.zig` — SV32 page table map/unmap, `VAddr`/`PAddr` types
- Public API is struct-based: `arch.Paging`, `arch.Trap`, `arch.Syscall`, `arch.Context`, `arch.Console`.
- External code references types as `arch.Paging.VAddr`, `arch.Trap.Frame`, etc.
- Every future architecture implements the same struct namespaces under its own `arch.zig`.
- Paging map/unmap allocates intermediate page tables via `allocator.allocPages`.
- Adding a new architecture: create a directory under `src/arch/`, implement the same struct API, and add an `arch_path` entry in `build.zig`.
