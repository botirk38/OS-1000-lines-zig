const common = @import("common.zig");
const memory = @import("memory.zig");

const procs_max = 8;
const user_base = 0x1000000;
const stack_size = 8192;

const PageFlags = memory.PageFlags;

pub const Process = struct {
    pid: i32,
    state: i32,
    sp: u32,
    stack: [stack_size]u8,
    page_table: [*]u32,
    image_size: usize = 0,

    pub fn create(entry_point: u32, image: ?[]const u8) ?*Process {
        for (0..procs_max) |i| {
            if (procs[i].state == 0) {
                return initProcess(i, entry_point, image);
            }
        }
        common.panic("no free process slots", .{});
    }

    fn initProcess(index: usize, entry: u32, image: ?[]const u8) *Process {
        const p = &procs[index];

        // Set up stack pointer as [*]u32 aligned to word boundary
        var sp: [*]u32 = @ptrCast(@alignCast(&p.stack));
        sp += stack_size / @sizeOf(u32);

        // Push 13 callee-saved registers (s0-s11 + ra), zeroed
        for (0..13) |_| {
            sp -= 1;
            sp[0] = 0;
        }

        // Push return address (entry point)
        sp -= 1;
        sp[0] = entry;

        // Allocate and align page table
        const pt_slice = memory.allocPages(1);
        const pt: [*]u32 = @ptrCast(@alignCast(pt_slice.ptr));

        // Map kernel pages into user page table
        const kernel_base = @intFromPtr(@extern([*]u8, .{ .name = "__kernel_base" }));
        const free_ram_end = @intFromPtr(@extern([*]u8, .{ .name = "__free_ram_end" }));

        var paddr: u32 = @intCast(kernel_base);
        while (paddr < free_ram_end) : (paddr += memory.PAGE_SIZE) {
            memory.mapPage(pt, paddr, paddr, @intFromEnum(PageFlags.read) |
                @intFromEnum(PageFlags.write) |
                @intFromEnum(PageFlags.exec));
        }

        // Load image if provided
        if (image) |img| {
            var off: usize = 0;
            while (off < img.len) {
                const page = memory.allocPages(1);
                const copy_len = @min(memory.PAGE_SIZE, img.len - off);
                @memcpy(page[0..copy_len], img[off..][0..copy_len]);
                const offset: u32 = @intCast(off);
                const vaddr = user_base + offset;
                memory.mapPage(pt, vaddr, @intFromPtr(page.ptr), @intFromEnum(PageFlags.read) |
                    @intFromEnum(PageFlags.write) |
                    @intFromEnum(PageFlags.exec) |
                    @intFromEnum(PageFlags.user));

                off += memory.PAGE_SIZE;
            }
            p.image_size = img.len;
        }

        p.* = .{
            .pid = @intCast(index + 1),
            .state = 1,
            .sp = @intFromPtr(sp),
            .page_table = pt,
            .image_size = p.image_size,
        };
        return p;
    }
};

var procs: [procs_max]Process = undefined;
pub var current_proc: ?*Process = null;
pub var idle_proc: ?*Process = null;

pub fn init() void {
    idle_proc = Process.create(0, null);
    if (idle_proc) |p| p.pid = 0;
    current_proc = idle_proc;
}
