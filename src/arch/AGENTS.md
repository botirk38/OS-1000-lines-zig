# arch — Agent Guidance

- The `interface.zig` module validates that `riscv32.zig` exports all required symbols.
- Assembly routines (`switch_context`, `kernelEntry`, `boot`) are in `comptime` blocks.
- Paging map/unmap allocates intermediate page tables via `allocator.allocPages`.
- Adding a new architecture: implement the interface and add an `arch_path` entry in `build.zig`.
