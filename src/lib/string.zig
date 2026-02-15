const std = @import("std");

pub fn stringCopy(dest: []u8, src: []const u8) []u8 {
    const len = @min(dest.len, src.len);
    @memcpy(dest[0..len], src[0..len]);
    return dest[0..len];
}

pub fn stringCompare(a: []const u8, b: []const u8) std.math.Order {
    return std.mem.order(u8, a, b);
}
