const sbi = @import("sbi");

pub const Console = struct {
    pub fn putChar(c: u8) void {
        sbi.putChar(c);
    }

    pub fn getChar() i32 {
        return sbi.getChar();
    }

    pub fn shutdown() noreturn {
        sbi.shutdown();
    }
};

pub const putChar = Console.putChar;
pub const getChar = Console.getChar;
pub const shutdown = Console.shutdown;
