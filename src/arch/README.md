# arch — RISC-V Architecture Layer

Architecture-specific code for RISC-V 32-bit, split into domain files under `rv32/`:

All types are exposed through struct-based namespaces:

| Namespace | File | Key types |
|-----------|------|-----------|
| `arch.Paging` | `paging.zig` | `VAddr`, `PAddr`, `Root`, `Flag`, `Error` |
| `arch.Trap` | `trap.zig` | `Frame`, `Exception`, `Interrupt`, `Kind`, `Info` |
| `arch.Syscall` | `trap.zig` | `syscall number/arg/setReturn` helpers |
| `arch.Context` | `context.zig` | `swap`, `activateAddressSpace` |
| `arch.Sbi` | `sbi.zig` | `putChar`, `getChar`, `shutdown` |

Private implementation files: `csr.zig` (CSR read/write).

All kernel code imports via `@import("arch")` — no per-file imports needed.
