pub const Word = u32;

pub const Paging = @import("paging.zig").Paging;
pub const Trap = @import("trap.zig").Trap;
pub const Syscall = @import("trap.zig").Syscall;
pub const Context = @import("context.zig").Context;
pub const Sbi = @import("sbi.zig").Sbi;
