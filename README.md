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

### Installation Instructions

#### Ubuntu/Debian
```bash
# Install QEMU and LLVM tools
sudo apt update
sudo apt install qemu-system-misc llvm

# Verify QEMU RISC-V support
qemu-system-riscv32 --version
```

#### macOS (with Homebrew)
```bash
# Install QEMU and LLVM
brew install qemu llvm

# Add LLVM to PATH (for objcopy)
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
```

#### Arch Linux
```bash
# Install QEMU and LLVM
sudo pacman -S qemu-system-riscv llvm

# Verify installation
qemu-system-riscv32 --version
```

#### Installing Zig
```bash
# Download Zig 0.15.1+ from https://ziglang.org/download/
# For Linux x86_64:
wget https://ziglang.org/download/0.15.1/zig-linux-x86_64-0.15.1.tar.xz
tar -xf zig-linux-x86_64-0.15.1.tar.xz
sudo mv zig-linux-x86_64-0.15.1 /opt/zig
export PATH="/opt/zig:$PATH"

# For macOS (or use brew install zig):
# wget https://ziglang.org/download/0.15.1/zig-macos-x86_64-0.15.1.tar.xz

# Verify Zig installation
zig version
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

## QEMU Setup and Usage

### QEMU Configuration

The kernel runs in QEMU with the following configuration:
- **Architecture**: RISC-V 32-bit (`qemu-system-riscv32`)
- **Machine**: `virt` (RISC-V virtual platform)
- **BIOS**: Default OpenSBI firmware
- **Memory**: 128MB default
- **Serial**: Console output via UART (stdio)
- **Monitor**: Telnet interface on port 55556

### Running the Kernel

```bash
# Automated run (recommended)
zig build run

# Manual QEMU invocation (equivalent to above)
qemu-system-riscv32 \
  -machine virt \
  -bios default \
  -serial mon:stdio \
  -monitor telnet:127.0.0.1:55556,server,nowait \
  --no-reboot \
  -nographic \
  -kernel zig-out/bin/kernel.elf
```

### QEMU Controls

- **Exit QEMU**: `Ctrl+A, X`
- **Monitor interface**: Connect to `telnet localhost 55556`
- **Pause/Resume**: `Ctrl+A, S` / `Ctrl+A, R`
- **Reset**: `Ctrl+A, R` (or use monitor command `system_reset`)

### Expected Output

When running successfully, you should see:
```
OpenSBI v1.3.1
...
[rk] booting kernel...
Hello from user space!
User process running...
```

### Troubleshooting

#### QEMU Not Found
```bash
# Verify QEMU is installed with RISC-V support
qemu-system-riscv32 --version
which qemu-system-riscv32

# On some systems, try:
sudo apt install qemu-system-riscv32  # Debian-based
brew install qemu                     # macOS
```

#### Build Errors
```bash
# Clean and rebuild
rm -rf zig-cache zig-out
zig build

# Check Zig version (needs 0.15.1+)
zig version
```

#### No Output
- Ensure your terminal supports the console output
- Try running with `-serial stdio` instead of `-serial mon:stdio`
- Check that OpenSBI loads (you should see OpenSBI banner)

#### Permission Issues
```bash
# On some Linux systems, add user to kvm group for better performance
sudo usermod -a -G kvm $USER
# Logout and login again
```

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
