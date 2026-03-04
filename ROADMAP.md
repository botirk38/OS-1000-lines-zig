# pico-os Roadmap

## Current Status

pico-os is a minimal RISC-V 32-bit OS written in Zig that demonstrates core OS concepts.

### Implemented Features

- [x] QEMU boot (riscv32)
- [x] SV32 paging
- [x] Basic memory allocator
- [x] Round-robin process scheduling
- [x] User mode with trap handling
- [x] Basic syscalls (write, read, yield, exit)

## Future Goals

### Short Term
- Additional syscalls (fork, exec, wait)
- File system support
- Improved shell

### Medium Term
- Memory protection between processes
- Inter-process communication
- Better error handling

### Long Term
- Multi-core support
- Network stack
- POSIX compatibility layer
