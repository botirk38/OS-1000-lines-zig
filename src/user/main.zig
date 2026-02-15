export fn start() linksection(".text.start") callconv(.naked) void {
    asm volatile (
        \\call main
    );
}

export fn main() noreturn {
    var counter: u32 = 0;
    while (true) {
        counter += 1;
        if (counter % 100000000 == 0) {
            asm volatile ("nop");
        }
    }
}
