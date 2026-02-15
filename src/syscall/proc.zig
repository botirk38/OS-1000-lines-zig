pub fn exit(code: i32) noreturn {
    _ = code;
    @panic("TODO: implement sys_exit");
}

pub fn yield() void {
    @panic("TODO: implement sys_yield");
}
