const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });
const kernel_base = @extern([*]u8, .{ .name = "__kernel_base" });

const common = @import("common.zig");

// Memory alloc defintions
var next_free_paddr: u32 = undefined;
const PAGE_SIZE: u32 = 4096;

// Page Table definitions

const SATP_SV32 = 1 << 31;
const PAGE_V: u32 = 1 << 0; // Valid bit
const PAGE_R: u32 = 1 << 1; // Readable
const PAGE_W: u32 = 1 << 2; // Writable
const PAGE_X: u32 = 1 << 3; // Executable
const PAGE_U: u32 = 1 << 4; // User (accessible in user mode)

// Process definitions
const PROCS_MAX = 8; // Maximum number of processes
const PROC_UNUSED = 0; // Unused process control structure
const PROC_RUNNABLE = 1; // Runnable process
const STACK_SIZE = 8192; // 8KB

// All process control blocks
var procs: [PROCS_MAX]Process = undefined;

// Currently running process
pub var current_proc: ?*Process = null;

// Idle process
pub var idle_proc: ?*Process = null;

fn is_aligned(addr: u32, size: u32) bool {
    return addr & (size - 1) == 0;
}

fn map_page(table1: [*]u32, vaddr: u32, paddr: u32, flags: u32) void {
    if (!is_aligned(vaddr, PAGE_SIZE)) {
        panic("unaligned vaddr {x}", .{vaddr});
    }

    if (!is_aligned(paddr, PAGE_SIZE)) {
        panic("unaligned paddr {x}", .{paddr});
    }

    const vpn1 = (vaddr >> 22) & 0x3ff;

    if ((table1[vpn1] & PAGE_V) == 0) {
        // Create the non-existent 2nd level page table
        const pt_paddr: u32 = @intFromPtr(alloc_pages(1));
        table1[vpn1] = ((pt_paddr / PAGE_SIZE) << 10) | PAGE_V;
    }
    const vpn0 = (vaddr >> 12) & 0x3ff;

    const table0_paddr = (table1[vpn1] >> 10) * PAGE_SIZE;
    const table0: [*]u32 = @ptrFromInt(table0_paddr);
    table0[vpn0] = ((paddr / PAGE_SIZE) << 10) | flags | PAGE_V;
}

const Process = struct {
    pid: i32, // Process ID
    state: i32, // Process state: PROC_UNUSED or PROC_RUNNABLE
    sp: u32, // Stack pointer
    stack: [STACK_SIZE]u8, // Kernel stacka
    page_table: [*]u32,

    pub fn create(entry_point: u32) ?*Process {
        // Find an unused process slot
        const proc_idx = for (0..PROCS_MAX) |i| {
            if (procs[i].state == PROC_UNUSED) {
                break i;
            }
        } else {
            panic("no free process slots", .{});
        };

        const p = &procs[proc_idx];

        // Setup stack (grows downward)
        const stack_ptr: [*]u8 = @ptrCast(&p.stack);
        var sp = @as([*]u32, @alignCast(@ptrCast(stack_ptr))) + (p.stack.len / @sizeOf(u32));

        // Push callee-saved registers (s0-s11) - all zeroed
        for (0..12) |_| {
            sp -= 1;
            sp[0] = 0;
        }

        // Set return address to entry point
        sp -= 1;
        sp[0] = entry_point;

        // Create page table
        const page_table = @as([*]u32, @alignCast(@ptrCast(alloc_pages(1))));

        // Map kernel pages
        const free_ram_end_addr: usize = @intFromPtr(free_ram_end);

        var paddr: u32 = @intFromPtr(kernel_base);

        while (paddr < free_ram_end_addr) : (paddr += PAGE_SIZE) {
            map_page(page_table, paddr, paddr, PAGE_R | PAGE_W | PAGE_X);
        }

        // Initialize process
        p.pid = @intCast(proc_idx + 1);
        p.state = PROC_RUNNABLE;
        p.sp = @intFromPtr(sp);
        p.page_table = page_table;

        return p;
    }

    pub fn switchContext(prev_sp: *u32, next_sp: *u32) void {
        asm volatile (
            \\addi sp, sp, -13 * 4
            \\sw ra,  0  * 4(sp)
            \\sw s0,  1  * 4(sp)
            \\sw s1,  2  * 4(sp)
            \\sw s2,  3  * 4(sp)
            \\sw s3,  4  * 4(sp)
            \\sw s4,  5  * 4(sp)
            \\sw s5,  6  * 4(sp)
            \\sw s6,  7  * 4(sp)
            \\sw s7,  8  * 4(sp)
            \\sw s8,  9  * 4(sp)
            \\sw s9,  10 * 4(sp)
            \\sw s10, 11 * 4(sp)
            \\sw s11, 12 * 4(sp)
            \\sw sp, (%[prev_sp])
            \\lw sp, (%[next_sp])
            \\lw ra,  0  * 4(sp)
            \\lw s0,  1  * 4(sp)
            \\lw s1,  2  * 4(sp)
            \\lw s2,  3  * 4(sp)
            \\lw s3,  4  * 4(sp)
            \\lw s4,  5  * 4(sp)
            \\lw s5,  6  * 4(sp)
            \\lw s6,  7  * 4(sp)
            \\lw s7,  8  * 4(sp)
            \\lw s8,  9  * 4(sp)
            \\lw s9,  10 * 4(sp)
            \\lw s10, 11 * 4(sp)
            \\lw s11, 12 * 4(sp)
            \\addi sp, sp, 13 * 4
            :
            : [prev_sp] "r" (prev_sp),
              [next_sp] "r" (next_sp),
        );
    }
};

// Yield the CPU to another runnable process

pub fn yield() void {
    // If no current process, can't yield
    if (current_proc == null) return;

    // Search for a runnable process
    var next = idle_proc;
    var i: i32 = 0;
    while (i < PROCS_MAX) : (i += 1) {
        const pid: i32 = current_proc.?.pid;
        const proc_idx = @mod(pid + i, @as(i32, PROCS_MAX));
        const proc = &procs[@intCast(proc_idx)];
        if (proc.state == PROC_RUNNABLE and proc.pid > 0) {
            next = proc;
            break;
        }
    }

    // If there's no runnable process other than the current one, return
    if (next == current_proc) return;

    // Context switch and page table switch
    const prev = current_proc;
    current_proc = next;

    // Switch page tables using sfence.vma for TLB flush
    asm volatile (
        \\sfence.vma
        \\csrw satp, %[satp]
        \\sfence.vma
        \\csrw sscratch, %[sscratch]
        :
        : [satp] "r" (SATP_SV32 | (@intFromPtr(next.?.page_table) / PAGE_SIZE)),
          [sscratch] "r" (@intFromPtr(&next.?.stack) + next.?.stack.len),
    );

    Process.switchContext(&prev.?.sp, &next.?.sp);
}

// Initialize the process system
pub fn init() void {
    // Setup idle process
    idle_proc = Process.create(0);
    if (idle_proc) |proc| {
        proc.pid = 0; // mark as idle process
    }
    current_proc = idle_proc;
}

const SbiCall = struct {
    a0: u32 = 0,
    a1: u32 = 0,
    a2: u32 = 0,
    a3: u32 = 0,
    a4: u32 = 0,
    a5: u32 = 0,
    fid: u32,
    eid: u32,
};

const SbiRet = struct {
    err: u32,
    value: u32,
};

const TrapFrame = packed struct {
    ra: u32,
    gp: u32,
    tp: u32,
    t0: u32,
    t1: u32,
    t2: u32,
    t3: u32,
    t4: u32,
    t5: u32,
    t6: u32,
    a0: u32,
    a1: u32,
    a2: u32,
    a3: u32,
    a4: u32,
    a5: u32,
    a6: u32,
    a7: u32,
    s0: u32,
    s1: u32,
    s2: u32,
    s3: u32,
    s4: u32,
    s5: u32,
    s6: u32,
    s7: u32,
    s8: u32,
    s9: u32,
    s10: u32,
    s11: u32,
    sp: u32,
};

pub fn put_char(ch: u8) void {
    _ = sbi_call(.{ .a0 = ch, .a1 = 0, .a2 = 0, .a3 = 0, .a4 = 0, .a5 = 0, .fid = 0, .eid = 1 });
}

fn sbi_call(args: SbiCall) SbiRet {
    var err: u32 = undefined;
    var val: u32 = undefined;
    asm volatile ("ecall"
        : [err] "={a0}" (err),
          [val] "={a1}" (val),
        : [arg0] "{a0}" (args.a0),
          [arg1] "{a1}" (args.a1),
          [arg2] "{a2}" (args.a2),
          [arg3] "{a3}" (args.a3),
          [arg4] "{a4}" (args.a4),
          [arg5] "{a5}" (args.a5),
          [fid] "{a6}" (args.fid),
          [eid] "{a7}" (args.eid),
        : "memory"
    );
    return .{ .err = err, .value = val };
}

// Read a CSR register
fn readCsr(comptime reg: []const u8) u32 {
    return asm volatile ("csrr %[ret], " ++ reg
        : [ret] "=r" (-> u32),
    );
}

// Write to a CSR register
fn writeCsr(comptime reg: []const u8, value: u32) void {
    asm volatile ("csrw " ++ reg ++ ", %[val]"
        :
        : [val] "r" (value),
    );
}

// Handle the trap/exception
export fn handleTrap(frame: *TrapFrame) callconv(.C) void {
    const scause = readCsr("scause");
    const stval = readCsr("stval");
    const user_pc = readCsr("sepc");

    // Print some relevant registers from the frame
    panic("trap: scause={x}, stval={x}, sepc={x}, ra={x}, sp={x}", .{ scause, stval, user_pc, frame.ra, frame.sp });
}

// Exception entry point
fn kernelEntry() callconv(.Naked) void {
    asm volatile (
        \\csrw sscratch, sp
        \\addi sp, sp, -4 * 31
        \\sw ra,  4 * 0(sp)
        \\sw gp,  4 * 1(sp)
        \\sw tp,  4 * 2(sp)
        \\sw t0,  4 * 3(sp)
        \\sw t1,  4 * 4(sp)
        \\sw t2,  4 * 5(sp)
        \\sw t3,  4 * 6(sp)
        \\sw t4,  4 * 7(sp)
        \\sw t5,  4 * 8(sp)
        \\sw t6,  4 * 9(sp)
        \\sw a0,  4 * 10(sp)
        \\sw a1,  4 * 11(sp)
        \\sw a2,  4 * 12(sp)
        \\sw a3,  4 * 13(sp)
        \\sw a4,  4 * 14(sp)
        \\sw a5,  4 * 15(sp)
        \\sw a6,  4 * 16(sp)
        \\sw a7,  4 * 17(sp)
        \\sw s0,  4 * 18(sp)
        \\sw s1,  4 * 19(sp)
        \\sw s2,  4 * 20(sp)
        \\sw s3,  4 * 21(sp)
        \\sw s4,  4 * 22(sp)
        \\sw s5,  4 * 23(sp)
        \\sw s6,  4 * 24(sp)
        \\sw s7,  4 * 25(sp)
        \\sw s8,  4 * 26(sp)
        \\sw s9,  4 * 27(sp)
        \\sw s10, 4 * 28(sp)
        \\sw s11, 4 * 29(sp)
        \\csrr a0, sscratch
        \\sw a0, 4 * 30(sp)
        \\mv a0, sp
        \\call handleTrap
        \\lw ra,  4 * 0(sp)
        \\lw gp,  4 * 1(sp)
        \\lw tp,  4 * 2(sp)
        \\lw t0,  4 * 3(sp)
        \\lw t1,  4 * 4(sp)
        \\lw t2,  4 * 5(sp)
        \\lw t3,  4 * 6(sp)
        \\lw t4,  4 * 7(sp)
        \\lw t5,  4 * 8(sp)
        \\lw t6,  4 * 9(sp)
        \\lw a0,  4 * 10(sp)
        \\lw a1,  4 * 11(sp)
        \\lw a2,  4 * 12(sp)
        \\lw a3,  4 * 13(sp)
        \\lw a4,  4 * 14(sp)
        \\lw a5,  4 * 15(sp)
        \\lw a6,  4 * 16(sp)
        \\lw a7,  4 * 17(sp)
        \\lw s0,  4 * 18(sp)
        \\lw s1,  4 * 19(sp)
        \\lw s2,  4 * 20(sp)
        \\lw s3,  4 * 21(sp)
        \\lw s4,  4 * 22(sp)
        \\lw s5,  4 * 23(sp)
        \\lw s6,  4 * 24(sp)
        \\lw s7,  4 * 25(sp)
        \\lw s8,  4 * 26(sp)
        \\lw s9,  4 * 27(sp)
        \\lw s10, 4 * 28(sp)
        \\lw s11, 4 * 29(sp)
        \\lw sp,  4 * 30(sp)
        \\sret
    );
}

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    // Get source file and line information using compiler builtins
    const src = @src();

    // Print panic message
    common.printf("PANIC: {s}:{d}: ", .{ src.file, src.line });
    common.printf(fmt, args);
    common.printf("\n", .{});

    // Halt the system
    while (true) {
        asm volatile ("wfi");
    }
}

fn alloc_pages(n: u32) [*]u8 {
    // Global variable to track the next free address
    const paddr = next_free_paddr;
    next_free_paddr += n * PAGE_SIZE;

    // Check if we've run out of memory
    if (next_free_paddr > @intFromPtr(free_ram_end)) {
        panic("out of memory", .{});
    }

    // Calculate pointer to the allocated memory
    const ptr: [*]u8 = @ptrFromInt(paddr);

    // Zero the allocated memory
    const size = n * PAGE_SIZE;
    @memset(ptr[0..size], 0);

    return ptr;
}

// Delay function for testing
pub fn delay() void {
    for (0..30000000) |_| {
        asm volatile ("nop");
    }
}

var proc_a: ?*Process = null;
var proc_b: ?*Process = null;

// Process A entry function
fn procAEntry() callconv(.C) void {
    common.printf("starting process A\n", .{});
    while (true) {
        common.printf("Process {c}:\n", .{'A'});

        yield();
        delay();
    }
}

// Process B entry function
fn procBEntry() callconv(.C) void {
    common.printf("starting process B\n", .{});
    while (true) {
        common.printf("Process {c}:\n", .{'B'});

        yield();
        delay();
    }
}

export fn kernel_main() noreturn {
    const bss_len = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bss_len], 0);

    common.printf("\n\n", .{});

    // Initialize exception handler
    writeCsr("stvec", @intFromPtr(&kernelEntry));

    next_free_paddr = @intFromPtr(free_ram);

    // Initialize the process system
    init();

    // Create test processes
    proc_a = Process.create(@intFromPtr(&procAEntry));
    proc_b = Process.create(@intFromPtr(&procBEntry));

    // Start scheduling
    yield();

    // Should not reach here
    panic("switched to idle process", .{});
}

// Get information about free memory
fn getFreeMemoryInfo() struct { start: u32, end: u32, size: u32 } {
    return .{
        .start = @intFromPtr(free_ram),
        .end = @intFromPtr(free_ram_end),
        .size = @intFromPtr(free_ram_end) - @intFromPtr(free_ram),
    };
}

export fn boot() linksection(".text.boot") callconv(.Naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_main
        :
        : [stack_top] "r" (stack_top),
    );
}
