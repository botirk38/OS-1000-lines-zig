const sbi = @import("sbi");

pub fn writeString(str: []const u8) void {
    for (str) |c| {
        sbi.putChar(c);
    }
}

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    comptime var i: usize = 0;
    comptime var arg_index: usize = 0;

    inline while (i < fmt.len) {
        if (fmt[i] == '{') {
            if (i + 1 < fmt.len and fmt[i + 1] == '}') {
                if (arg_index < args.len) {
                    const arg = @field(args, @typeInfo(@TypeOf(args)).@"struct".fields[arg_index].name);
                    printValue(arg);
                    arg_index += 1;
                }
                i += 2;
            } else if (i + 2 < fmt.len and fmt[i + 1] == 'x' and fmt[i + 2] == '}') {
                if (arg_index < args.len) {
                    const arg = @field(args, @typeInfo(@TypeOf(args)).@"struct".fields[arg_index].name);
                    printHex(arg);
                    arg_index += 1;
                }
                i += 3;
            } else {
                sbi.putChar(fmt[i]);
                i += 1;
            }
        } else {
            sbi.putChar(fmt[i]);
            i += 1;
        }
    }
}

fn printHex(value: anytype) void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .int => {
            const val: u32 = @intCast(value);
            sbi.putChar('0');
            sbi.putChar('x');

            const hex_chars = "0123456789abcdef";
            var printed_digit = false;

            var i: i8 = 28;
            while (i >= 0) : (i -= 4) {
                const nibble = @as(u8, @intCast((val >> @intCast(i)) & 0xF));
                if (nibble != 0 or printed_digit or i == 0) {
                    sbi.putChar(hex_chars[nibble]);
                    printed_digit = true;
                }
            }
        },
        .comptime_int => {
            printHex(@as(u32, value));
        },
        else => {
            sbi.putChar('?');
        },
    }
}

fn printValue(value: anytype) void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .int => {
            if (value == 0) {
                sbi.putChar('0');
                return;
            }

            var val = value;
            var buf: [20]u8 = undefined;
            var pos: usize = 0;
            var is_negative = false;

            if (val < 0) {
                is_negative = true;
                val = -val;
            }

            while (val > 0) {
                buf[pos] = @as(u8, @intCast(val % 10)) + '0';
                val = @divTrunc(val, 10);
                pos += 1;
            }

            if (is_negative) {
                sbi.putChar('-');
            }

            while (pos > 0) {
                pos -= 1;
                sbi.putChar(buf[pos]);
            }
        },
        .comptime_int => {
            printValue(@as(i32, value));
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice and ptr_info.child == u8) {
                writeString(value);
            } else {
                sbi.putChar('?');
            }
        },
        .array => |arr_info| {
            if (arr_info.child == u8) {
                writeString(&value);
            } else {
                sbi.putChar('?');
            }
        },
        else => {
            sbi.putChar('?');
        },
    }
}
