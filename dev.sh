#!/bin/bash

# OS-1000-Lines-Zig Development Helper Script
# This script provides common development tasks for the project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v zig &> /dev/null; then
        log_error "Zig is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v qemu-system-riscv32 &> /dev/null; then
        log_error "qemu-system-riscv32 is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v llvm-objdump &> /dev/null; then
        log_error "llvm-objdump is not installed or not in PATH"
        exit 1
    fi
    
    log_success "All dependencies are available"
}

build_kernel() {
    log_info "Building kernel..."
    zig build
    log_success "Kernel built successfully"
}

run_kernel() {
    log_info "Starting kernel in QEMU..."
    log_warning "Press Ctrl+A, X to exit QEMU"
    zig build run
}

test_kernel() {
    log_info "Running tests..."
    zig test src/common.zig
    log_success "Tests passed"
}

format_code() {
    log_info "Formatting code..."
    zig fmt src/
    log_success "Code formatted"
}

analyze_binary() {
    log_info "Analyzing kernel binary..."
    
    if [ ! -f "zig-out/bin/kernel.elf" ]; then
        log_error "Kernel binary not found. Run 'build' first."
        exit 1
    fi
    
    echo "Binary size:"
    ls -lh zig-out/bin/kernel.elf
    
    echo -e "\nSection headers:"
    llvm-objdump -h zig-out/bin/kernel.elf
    
    echo -e "\nSymbol table (sorted by size):"
    llvm-nm --size-sort zig-out/bin/kernel.elf | head -20
}

clean_build() {
    log_info "Cleaning build artifacts..."
    rm -rf zig-cache zig-out
    log_success "Build artifacts cleaned"
}

debug_kernel() {
    log_info "Starting kernel with GDB support..."
    log_warning "In another terminal, run: gdb-multiarch zig-out/bin/kernel.elf"
    log_warning "Then in GDB: target remote :1234"
    
    qemu-system-riscv32 \
        -machine virt \
        -bios default \
        -nographic \
        -serial mon:stdio \
        --no-reboot \
        -kernel zig-out/bin/kernel.elf \
        -s -S
}

quick_test() {
    log_info "Running quick smoke test..."
    build_kernel
    
    # Run kernel for 3 seconds to see if it boots
    timeout 3s qemu-system-riscv32 \
        -machine virt \
        -bios default \
        -nographic \
        -serial mon:stdio \
        --no-reboot \
        -kernel zig-out/bin/kernel.elf || true
    
    log_success "Quick test completed"
}

show_help() {
    echo "OS-1000-Lines-Zig Development Helper"
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  check       - Check if all dependencies are installed"
    echo "  build       - Build the kernel"
    echo "  run         - Build and run the kernel in QEMU"
    echo "  test        - Run unit tests"
    echo "  format      - Format source code"
    echo "  analyze     - Analyze kernel binary (size, sections, symbols)"
    echo "  clean       - Clean build artifacts"
    echo "  debug       - Start kernel with GDB support"
    echo "  quick       - Quick smoke test (build + 3s boot test)"
    echo "  help        - Show this help message"
}

# Main script logic
case "${1:-}" in
    "check")
        check_dependencies
        ;;
    "build")
        check_dependencies
        build_kernel
        ;;
    "run")
        check_dependencies
        build_kernel
        run_kernel
        ;;
    "test")
        check_dependencies
        test_kernel
        ;;
    "format")
        format_code
        ;;
    "analyze")
        analyze_binary
        ;;
    "clean")
        clean_build
        ;;
    "debug")
        check_dependencies
        build_kernel
        debug_kernel
        ;;
    "quick")
        check_dependencies
        quick_test
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        log_error "No command specified"
        show_help
        exit 1
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac