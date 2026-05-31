const Word = @import("arch.zig").Word;

pub fn read(comptime reg: []const u8) Word {
    return asm volatile ("csrr %[ret], " ++ reg
        : [ret] "=r" (-> Word),
    );
}

pub fn write(comptime reg: []const u8, value: Word) void {
    asm volatile ("csrw " ++ reg ++ ", %[val]"
        :
        : [val] "r" (value),
    );
}
