//! User space program
//! Simple user program that demonstrates process execution

const console = @import("hal/console.zig");

/// User program entry point
export fn main() noreturn {
    console.writeString("Hello from user space!\n");

    // Simple loop to demonstrate user space execution
    var counter: u32 = 0;
    while (true) {
        counter += 1;
        if (counter % 10000000 == 0) {
            console.writeString("User process running...\n");
        }
    }
}