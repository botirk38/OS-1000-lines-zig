# OS-1000-Lines-Zig Development Roadmap

## Project Overview

This project is a Zig implementation of the "Operating System in 1,000 Lines" tutorial, targeting RISC-V 32-bit architecture. The goal is to build a minimal but functional operating system demonstrating core OS concepts with clean, modern Zig code.

## Current Implementation Status

### ✅ Completed Features

#### 1. **Boot Process & Kernel Foundation** (Chapters 1-4)
- [x] RISC-V 32-bit target configuration 
- [x] OpenSBI integration via QEMU
- [x] Kernel entry point with proper stack setup
- [x] BSS section initialization
- [x] Linker script configuration (`kernel.ld`)
- [x] Build system with Zig build tool

#### 2. **Console Output & SBI Integration** (Chapter 5)
- [x] SBI console putchar interface (`platform/sbi.zig`)
- [x] Hardware Abstraction Layer for console (`hal/console.zig`)
- [x] Printf-style formatted output
- [x] "Hello World" kernel output capability

#### 3. **Error Handling & Debugging** (Chapters 6-7)
- [x] Kernel panic implementation (`debug/panic.zig`)
- [x] Basic trap frame structure
- [x] Trap handler skeleton (panic on any trap)
- [x] Debug utilities and assertion handling

#### 4. **Memory Management Foundation** (Chapter 9)
- [x] Page-based memory allocator (`mm/allocator.zig`)
- [x] SV32 virtual memory paging (`mm/paging.zig`)
- [x] Page table management
- [x] Memory layout definitions and constants

#### 5. **Process Management** (Multitasking)
- [x] Process Control Block (PCB) structure
- [x] Basic process creation with ELF loading
- [x] Context switching implementation
- [x] Round-robin scheduler
- [x] User space process execution with proper privilege separation
- [x] Kernel/user space separation with RISC-V sret instruction
- [x] Clean scheduler/process module architecture
- [x] Memory protection enforcement (page faults on unauthorized access)

#### 6. **User Programs**
- [x] User space program compilation (`user.zig`)
- [x] User binary embedding in kernel
- [x] User process execution in protected mode
- [⚠️] **SECURITY ISSUE**: User program currently imports kernel modules (needs fix)

#### 7. **Architecture & Platform Support**
- [x] RISC-V 32-bit specific code (`arch/riscv32.zig`)
- [x] CSR (Control and Status Register) operations
- [x] Assembly routines for context switching
- [x] RISC-V trap handling framework

## 🚧 Missing Features (To Implement)

### Priority 1: Core System Calls
- [ ] **URGENT: Fix user program security** - remove kernel module imports from user.zig
- [ ] **System call interface** - ecall instruction handling in trap handler
- [ ] **User/kernel mode transitions** - enhance existing sret-based transitions
- [ ] **Basic syscalls**: `write`, `read`, `exit`, `yield`
- [ ] **System call dispatcher** in trap handler (distinguish from page faults)

### Priority 2: Interrupt & Exception Handling
- [ ] **Timer interrupts** - for preemptive scheduling
- [ ] **Exception handling** - proper fault handling vs panics
- [ ] **Interrupt controller** - RISC-V PLIC support
- [ ] **Improved trap handler** - distinguish different trap causes

### Priority 3: I/O & Device Drivers
- [ ] **VirtIO block device driver** - for disk access
- [ ] **Device abstraction layer** - generic device interface
- [ ] **Polling-based I/O** - as per tutorial spec (no interrupts initially)

### Priority 4: File System
- [ ] **Simple file system** - basic directory/file operations
- [ ] **VFS (Virtual File System)** - abstraction layer
- [ ] **File operations**: create, read, write, delete
- [ ] **Directory operations**: list, create, remove

### Priority 5: Shell & User Interface
- [ ] **Command-line shell** - interactive user interface
- [ ] **Shell commands**: `ls`, `cat`, `echo`, `mkdir`, etc.
- [ ] **Command parsing and execution**
- [ ] **Built-in vs external commands**

### Priority 6: Advanced Features
- [ ] **Multiple user processes** - beyond single user program
- [ ] **Process lifecycle management** - proper exit handling
- [ ] **Memory protection** - prevent user space kernel access
- [ ] **Error recovery** - handle faults gracefully

## Implementation Plan

### Phase 1: System Calls (2-3 weeks)
**Goal**: Enable proper kernel/user communication

**IMMEDIATE (Days 1-2): Security Fix**
   - Remove kernel module imports from user.zig
   - Create safe user program that doesn't access kernel memory
   - Verify memory protection is working correctly

1. **Week 1**: Implement basic syscall infrastructure
   - Modify trap handler to detect ecall instructions (scause=8)
   - Create syscall dispatcher with numbered syscalls
   - Implement `sys_write` for user programs to output text
   - Add `sys_exit` for clean process termination

2. **Week 2**: Expand syscall interface
   - Add `sys_read` for user input (console)
   - Implement `sys_yield` for cooperative multitasking
   - Create user library wrappers (`user.zig` expansion)
   - Test multiple syscalls in user programs

3. **Week 3**: Stabilize and test
   - Comprehensive syscall testing
   - Error handling for invalid syscalls
   - Performance optimization
   - Documentation updates

### Phase 2: Device Drivers (2-3 weeks)
**Goal**: Enable disk I/O for file system foundation

1. **Week 1**: VirtIO infrastructure
   - Study VirtIO specification for RISC-V
   - Implement basic VirtIO device discovery
   - Set up VirtIO ring buffers

2. **Week 2**: Block device driver
   - Implement VirtIO block device driver
   - Add read/write operations
   - Create device abstraction layer
   - Basic testing with raw disk access

3. **Week 3**: Integration and testing
   - Integrate with memory management
   - Test disk I/O operations
   - Error handling and recovery
   - Performance benchmarking

### Phase 3: File System (3-4 weeks)
**Goal**: Implement basic file system operations

1. **Week 1**: File system design
   - Design simple file system layout
   - Implement superblock and inode structures
   - Create file system formatting tools

2. **Week 2**: Core file operations
   - Implement file create/open/close
   - Add read/write operations
   - Directory operations (list, create)

3. **Week 3**: VFS integration
   - Create Virtual File System layer
   - Implement path resolution
   - Add file system mounting

4. **Week 4**: Testing and optimization
   - Comprehensive file system testing
   - Performance optimization
   - Error handling and recovery

### Phase 4: Shell Interface (2 weeks)
**Goal**: Provide user-friendly command-line interface

1. **Week 1**: Basic shell
   - Implement command-line parsing
   - Add basic commands: `ls`, `cat`, `echo`
   - Command execution framework

2. **Week 2**: Advanced shell features
   - Add more commands: `mkdir`, `rm`, `cp`
   - Implement command history
   - Error handling and user feedback

### Phase 5: Polish & Advanced Features (2-3 weeks)
**Goal**: Complete the OS to tutorial standards

1. **Week 1**: Multiple processes
   - Support for multiple concurrent user processes
   - Improve scheduler with better algorithms
   - Process lifecycle management

2. **Week 2**: Memory protection & security
   - Implement proper memory protection
   - Prevent user space from accessing kernel memory
   - Add user/kernel privilege enforcement

3. **Week 3**: Final testing & documentation
   - Comprehensive system testing
   - Performance benchmarking
   - Complete documentation update
   - Tutorial compliance verification

## Technical Debt & Improvements

### Code Quality
- [ ] **Error handling consistency** - standardize error types across modules
- [ ] **Memory safety** - ensure no memory leaks in allocator
- [ ] **Code documentation** - add comprehensive module documentation
- [ ] **Unit testing** - add Zig unit tests where applicable

### Architecture Improvements  
- [ ] **Module dependencies** - clean up circular dependencies
- [ ] **Interface abstractions** - improve HAL layer consistency
- [ ] **Configuration management** - centralize system constants
- [ ] **Debugging support** - improve QEMU debugging integration

### Performance Optimizations
- [ ] **Context switch overhead** - optimize assembly routines
- [ ] **Memory allocation efficiency** - improve page allocator performance
- [ ] **I/O performance** - optimize device driver operations
- [ ] **Scheduler efficiency** - improve process selection algorithms

## Comparison with Original Tutorial

### Advantages of Zig Implementation
- ✅ **Type safety** - compile-time guarantees vs C undefined behavior
- ✅ **Memory safety** - explicit allocation and bounds checking  
- ✅ **Modern tooling** - integrated build system and package manager
- ✅ **Cross-compilation** - built-in RISC-V target support
- ✅ **Cleaner code** - explicit error handling and no hidden control flow

### Key Differences from C Version
- **Build system**: Using Zig build vs shell scripts
- **Memory management**: Explicit allocators vs raw malloc/free
- **Error handling**: Result types vs return codes
- **Assembly integration**: Inline assembly with better type safety
- **Module system**: Zig modules vs C header includes

## Testing Strategy

### Unit Testing
- [ ] **Memory allocator tests** - test allocation/deallocation patterns
- [ ] **Paging system tests** - test virtual memory operations
- [ ] **Utility function tests** - test common.zig functions
- [ ] **Data structure tests** - test process management structures

### Integration Testing  
- [ ] **Boot sequence tests** - verify proper kernel initialization
- [ ] **Process creation tests** - test user program loading and execution
- [ ] **System call tests** - verify kernel/user communication
- [ ] **File system tests** - test file operations end-to-end

### System Testing
- [ ] **Performance benchmarks** - measure context switch times, I/O throughput
- [ ] **Stress testing** - multiple processes, large files, memory pressure
- [ ] **Compatibility testing** - verify QEMU compatibility across versions
- [ ] **Regression testing** - ensure new features don't break existing functionality

## Tools & Dependencies

### Development Environment
- **Zig 0.15.1+** - Main compiler and build system
- **QEMU 8.0+** - RISC-V emulation (`qemu-system-riscv32`)
- **LLVM tools** - For binary analysis (`llvm-objdump`, `llvm-nm`)

### Optional Tools
- **GDB** - For advanced debugging (`gdb-multiarch`)
- **Spike** - Alternative RISC-V simulator for verification
- **Valgrind** - For memory debugging (if available for RISC-V)

## Success Criteria

### Minimum Viable Product (MVP)
- [ ] Boots successfully in QEMU
- [ ] Runs user programs with system calls
- [ ] Demonstrates multitasking between kernel and user space
- [ ] Basic file operations (create, read, write)
- [ ] Interactive shell with basic commands

### Complete Implementation
- [ ] Matches all features listed in original tutorial
- [ ] Demonstrates all major OS concepts (processes, memory, I/O, files)
- [ ] Stable operation under normal usage
- [ ] Clean, maintainable codebase
- [ ] Comprehensive documentation

### Stretch Goals
- [ ] **Performance competitive with C version**
- [ ] **Additional RISC-V features** (e.g., floating point, vector extensions)
- [ ] **Multi-core support** (SMP)
- [ ] **Network support** (VirtIO network device)
- [ ] **Graphics support** (VirtIO GPU)

---

**Last Updated**: September 22, 2025
**Current Status**: ✅ **MAJOR MILESTONE ACHIEVED** - User mode execution working with memory protection!
**Critical Issue**: ⚠️ User program security vulnerability (imports kernel modules)
**Next Milestone**: Fix security issue and implement system call interface (Phase 1)