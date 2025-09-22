# OS-1000-lines-zig

A minimal RISC-V operating system kernel written in Zig, demonstrating modern systems programming practices with clean modular architecture.

## Features

* **RISC-V 32-bit Architecture**: Native support for RISC-V with SV32 virtual memory
* **Process Management**: Basic process creation, scheduling, and context switching
* **Memory Management**: Page-based virtual memory with SV32 paging
* **SBI Interface**: Clean abstraction over RISC-V Supervisor Binary Interface
* **Modular Design**: Well-organized codebase following Zig best practices
* **Error Handling**: Proper error propagation and type safety

## Prerequisites

* **Zig 0.15.1+**: The Zig compiler
* **QEMU**: For RISC-V emulation (`qemu-system-riscv32`)
* **LLVM tools**: For binary conversion (`llvm-objcopy`)

### Installation on Ubuntu/Debian

```bash
# Install QEMU and LLVM tools
sudo apt update
sudo apt install qemu-system-misc llvm

# Install Zig (download from https://ziglang.org/download/)
wget https://ziglang.org/download/0.15.1/zig-linux-x86_64-0.15.1.tar.xz
tar -xf zig-linux-x86_64-0.15.1.tar.xz
sudo mv zig-linux-x86_64-0.15.1 /opt/zig
export PATH="/opt/zig:$PATH"
```

## Quick Start

```bash
# Clone the repository
git clone https://github.com/botirk38/OS-1000-lines-zig.git
cd OS-1000-lines-zig

# Build the kernel and user program
zig build

# Run in QEMU
zig build run
```

## Project Structure

```
src/
├── arch/           # Architecture-specific code
│   └── riscv32.zig # RISC-V 32-bit implementation
├── hal/            # Hardware Abstraction Layer
│   └── console.zig # Console I/O abstraction
├── mm/             # Memory Management
│   ├── allocator.zig # Page allocator
│   └── paging.zig    # Virtual memory management
├── proc/           # Process Management
│   └── process.zig   # Process creation and scheduling
├── platform/       # Platform-specific interfaces
│   └── sbi.zig      # RISC-V SBI interface
├── debug/          # Debug utilities
│   └── panic.zig    # Panic and assertion handling
├── common.zig      # Common utilities
├── kernel.zig      # Main kernel entry point
└── user.zig        # Simple user program
```

## Architecture

### Memory Layout
- **Kernel Space**: Virtual addresses 0x80000000+
- **User Space**: Virtual addresses 0x01000000+
- **Page Size**: 4KB with SV32 paging

### Process Model
- Simple round-robin scheduler
- Process creation with ELF loading
- Context switching via RISC-V CSRs

### Hardware Interface
- SBI calls for console I/O and system services
- Trap handling for exceptions and interrupts
- Virtual memory management with page tables

## Development

### Building
```bash
# Build only
zig build

# Build and run in QEMU
zig build run

# Clean build artifacts
rm -rf zig-cache zig-out
```

### Debugging
The kernel includes panic handling and debug assertions. Monitor output shows:
- Boot messages
- Process creation
- User space execution
- Panic information on errors

### Testing
```bash
# Run any Zig tests (if present)
zig test src/common.zig
```

## QEMU Usage

The kernel runs in QEMU with the following configuration:
- **Machine**: `virt` (RISC-V virtual platform)
- **BIOS**: Default OpenSBI
- **Serial**: Console output via UART
- **Monitor**: Telnet on port 55556

To exit QEMU: `Ctrl+A, X` or use the monitor interface.

## Contributing

This project demonstrates clean systems programming in Zig. Contributions should:

1. Follow Zig coding standards
2. Maintain modular architecture
3. Include proper error handling
4. Add documentation for new features

## License

MIT License - see LICENSE file for details.

## References

- [RISC-V Specification](https://riscv.org/specifications/)
- [Zig Language Reference](https://ziglang.org/documentation/)
- [SBI Specification](https://github.com/riscv-non-isa/riscv-sbi-doc)
