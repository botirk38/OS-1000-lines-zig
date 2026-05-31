const Paging = @import("paging.zig").Paging;
const Word = @import("arch.zig").Word;

comptime {
    asm (
        \\.global switch_context
        \\.type switch_context, @function
        \\switch_context:
        \\  addi sp, sp, -13 * 4
        \\  sw ra,  0  * 4(sp)
        \\  sw s0,  1  * 4(sp)
        \\  sw s1,  2  * 4(sp)
        \\  sw s2,  3  * 4(sp)
        \\  sw s3,  4  * 4(sp)
        \\  sw s4,  5  * 4(sp)
        \\  sw s5,  6  * 4(sp)
        \\  sw s6,  7  * 4(sp)
        \\  sw s7,  8  * 4(sp)
        \\  sw s8,  9  * 4(sp)
        \\  sw s9,  10 * 4(sp)
        \\  sw s10, 11 * 4(sp)
        \\  sw s11, 12 * 4(sp)
        \\  sw sp, (a0)
        \\  lw sp, (a1)
        \\  lw ra,  0  * 4(sp)
        \\  lw s0,  1  * 4(sp)
        \\  lw s1,  2  * 4(sp)
        \\  lw s2,  3  * 4(sp)
        \\  lw s3,  4  * 4(sp)
        \\  lw s4,  5  * 4(sp)
        \\  lw s5,  6  * 4(sp)
        \\  lw s6,  7  * 4(sp)
        \\  lw s7,  8  * 4(sp)
        \\  lw s8,  9  * 4(sp)
        \\  lw s9,  10 * 4(sp)
        \\  lw s10, 11 * 4(sp)
        \\  lw s11, 12 * 4(sp)
        \\  addi sp, sp, 13 * 4
        \\  ret
    );
}

pub extern fn switch_context(prev_sp: *Word, next_sp: *Word) void;

pub const Context = struct {
    pub fn swap(prev_sp: *Word, next_sp: *Word) void {
        switch_context(prev_sp, next_sp);
    }

    pub fn activateAddressSpace(root: Paging.Root, kernel_stack_top: Word) void {
        const satp = Paging.satpValue(root);
        asm volatile (
            \\sfence.vma
            \\csrw satp, %[satp]
            \\sfence.vma
            \\csrw sscratch, %[sscratch]
            :
            : [satp] "r" (satp),
              [sscratch] "r" (kernel_stack_top),
        );
    }
};
