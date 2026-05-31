# arch — Agent Guidance

- `arch` is an abstraction module; all implementations go in subdirectories (`rv32/`, etc.).
- The public API consists of five struct namespaces: `Paging`, `Trap`, `Syscall`, `Context`, `Console`.
- Kernel code imports `@import("arch")` and references types as `arch.Paging.VAddr`, `arch.Trap.Frame`, etc.
- Adding a new architecture: create a subdirectory with an `arch.zig` facade that exports the same five structs, then add an `arch_path` entry in `build.zig`.
