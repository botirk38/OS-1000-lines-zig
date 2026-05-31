# rv32 — RISC-V 32-bit Architecture Implementation

All types are exposed through struct-based namespaces:

| Namespace | File | Key types |
|-----------|------|-----------|
| `arch.Paging` | `paging.zig` | `VAddr`, `PAddr`, `Root`, `Flag`, `Error` |
| `arch.Trap` | `trap.zig` | `Frame`, `Exception`, `Interrupt`, `Kind`, `Info` |
| `arch.Syscall` | `trap.zig` | `number`, `arg`, `setReturn` |
| `arch.Context` | `context.zig` | `swap`, `activateAddressSpace` |
| `arch.Console` | `console.zig` | `putChar`, `getChar`, `shutdown` |

Internal modules:

- `sbi.zig` — raw RISC-V SBI ecall functions (private).
- `csr.zig` — CSR read/write wrappers (private).

Kernel code imports via `@import("arch")`.
