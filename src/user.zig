//! User space program
//! Simple user program that demonstrates process execution

/// User program entry point - assembly stub to call main
export fn start() linksection(".text.start") callconv(.naked) void {
    asm volatile (
        \\call main
    );
}

/// User program main function - simple infinite loop for now
export fn main() noreturn {
    // Simple loop to demonstrate user space execution
    // TODO: Add system calls for proper I/O
    var counter: u32 = 0;
    while (true) {
        counter += 1;
        // Just loop - no console access until we implement syscalls
        if (counter % 100000000 == 0) {
            // This will be replaced with a syscall later
            asm volatile ("nop");
        }
    }
}
