//! Compile-time-filtered kernel logger.
//!
//! Usage in a module:
//!
//!   const log = @import("logger");
//!   log.info("proc", "created pid={}", .{pid});
//!   log.debug("mm", "mapPage vaddr={x} paddr={x}", .{vaddr, paddr});
//!
//! Log level is set at build time with `-Dlog_level=<err|warn|info|debug>`.
//! Any call whose level is below the configured level compiles to nothing.
//!
//! Output format:  [LEVEL scope] message\n

const console = @import("console");
const build_options = @import("build_options");

/// Severity levels, ordered from least to most verbose.
pub const Level = enum(u8) {
    err = 0,
    warn = 1,
    info = 2,
    debug = 3,
};

/// The effective log level, resolved from the build option at comptime.
pub const configured_level: Level = blk: {
    const s = build_options.log_level;
    if (s.len == 3 and s[0] == 'e' and s[1] == 'r' and s[2] == 'r') break :blk .err;
    if (s.len == 4 and s[0] == 'w' and s[1] == 'a' and s[2] == 'r' and s[3] == 'n') break :blk .warn;
    if (s.len == 4 and s[0] == 'i' and s[1] == 'n' and s[2] == 'f' and s[3] == 'o') break :blk .info;
    if (s.len == 5 and s[0] == 'd' and s[1] == 'e' and s[2] == 'b' and s[3] == 'u' and s[4] == 'g') break :blk .debug;
    @compileError("Unknown log_level '" ++ s ++ "'. Valid values: err, warn, info, debug");
};

/// Core log function. The comptime level check means disabled levels emit no code.
pub fn log(
    comptime scope: []const u8,
    comptime lvl: Level,
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (comptime @intFromEnum(lvl) > @intFromEnum(configured_level)) return;

    const prefix = comptime switch (lvl) {
        .err => "[ERR  " ++ scope ++ "] ",
        .warn => "[WARN " ++ scope ++ "] ",
        .info => "[INFO " ++ scope ++ "] ",
        .debug => "[DBG  " ++ scope ++ "] ",
    };

    console.printf(prefix ++ fmt ++ "\n", args);
}

/// Log at error level.
pub fn err(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void {
    log(scope, .err, fmt, args);
}

/// Log at warning level.
pub fn warn(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void {
    log(scope, .warn, fmt, args);
}

/// Log at info level.
pub fn info(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void {
    log(scope, .info, fmt, args);
}

/// Log at debug level.
pub fn debug(comptime scope: []const u8, comptime fmt: []const u8, args: anytype) void {
    log(scope, .debug, fmt, args);
}
