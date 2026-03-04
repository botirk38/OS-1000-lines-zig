const layout = @import("layout");
const log = @import("logger");
const allocator = @import("allocator");
const math = @import("math");

const PAGE_SIZE = layout.PAGE_SIZE;

pub const VIRTIO_BLK_PADDR: u32 = 0x10001000;

const VIRTIO_REG_MAGIC: comptime_int = 0x00;
const VIRTIO_REG_VERSION: comptime_int = 0x04;
const VIRTIO_REG_DEVICE_ID: comptime_int = 0x08;
const VIRTIO_REG_PAGE_SIZE: comptime_int = 0x28;
const VIRTIO_REG_QUEUE_SEL: comptime_int = 0x30;
const VIRTIO_REG_QUEUE_NUM: comptime_int = 0x38;
const VIRTIO_REG_QUEUE_PFN: comptime_int = 0x40;
const VIRTIO_REG_QUEUE_NOTIFY: comptime_int = 0x50;
const VIRTIO_REG_DEVICE_STATUS: comptime_int = 0x70;
const VIRTIO_REG_DEVICE_CONFIG: comptime_int = 0x100;

const VIRTIO_STATUS_ACK: comptime_int = 1;
const VIRTIO_STATUS_DRIVER: comptime_int = 2;
const VIRTIO_STATUS_DRIVER_OK: comptime_int = 4;

const VIRTIO_DEVICE_BLK: comptime_int = 2;
const VIRTIO_MAGIC: u32 = 0x74726976;

const VIRTQ_DESC_F_NEXT: comptime_int = 1;
const VIRTQ_DESC_F_WRITE: comptime_int = 2;

const VIRTIO_BLK_T_IN: comptime_int = 0;
const VIRTIO_BLK_T_OUT: comptime_int = 1;

const VIRTQ_ENTRY_NUM: comptime_int = 16;
const SECTOR_SIZE: usize = 512;

pub const VirtIoError = error{
    BadMagic,
    BadVersion,
    NotBlockDevice,
    SectorOutOfRange,
    IoError,
};

const VirtIoBlkReqType = enum(u32) {
    read = VIRTIO_BLK_T_IN,
    write = VIRTIO_BLK_T_OUT,
};

const VirtqDesc = extern struct {
    addr: u64,
    len: u32,
    flags: u16,
    next: u16,
};

const VirtqAvail = extern struct {
    flags: u16,
    index: u16,
    ring: [VIRTQ_ENTRY_NUM]u16,
};

const VirtqUsedElem = extern struct {
    id: u32,
    len: u32,
};

const VirtqUsed = extern struct {
    flags: u16,
    index: u16,
    ring: [VIRTQ_ENTRY_NUM]VirtqUsedElem,
};

const Virtq = extern struct {
    descs: [VIRTQ_ENTRY_NUM]VirtqDesc,
    avail: VirtqAvail,
    _pad: [4096 - @sizeOf(VirtqAvail) - @sizeOf([VIRTQ_ENTRY_NUM]VirtqDesc)]u8,
    used: VirtqUsed,
    queue_index: u32,
    last_used_index: u16,
};

const VirtioBlkReq = extern struct {
    type: u32,
    reserved: u32,
    sector: u64,
    data: [SECTOR_SIZE]u8,
    status: u8,
    _pad: [7]u8,
};

pub const VirtioBlk = struct {
    request_vq: *Virtq,
    req: *VirtioBlkReq,
    req_paddr: u32,
    capacity: u64,

    fn regRead32(offset: u32) u32 {
        const ptr: *volatile u32 = @ptrFromInt(VIRTIO_BLK_PADDR + offset);
        return ptr.*;
    }

    fn regRead64(offset: u32) u64 {
        const ptr: *volatile u64 = @ptrFromInt(VIRTIO_BLK_PADDR + offset);
        return ptr.*;
    }

    fn regWrite32(offset: u32, value: u32) void {
        const ptr: *volatile u32 = @ptrFromInt(VIRTIO_BLK_PADDR + offset);
        ptr.* = value;
    }

    fn regFetchAndOr32(offset: u32, value: u32) void {
        regWrite32(offset, regRead32(offset) | value);
    }

    fn virtqInit(index: u32) *Virtq {
        const pages_needed = math.alignUp(@sizeOf(Virtq), PAGE_SIZE) / PAGE_SIZE;
        const vq_paddr = allocator.allocPages(pages_needed);
        const vq: *Virtq = @ptrFromInt(vq_paddr);

        vq.* = .{
            .descs = undefined,
            .avail = .{ .flags = 0, .index = 0, .ring = undefined },
            ._pad = undefined,
            .used = .{ .flags = 0, .index = 0, .ring = undefined },
            .queue_index = index,
            .last_used_index = 0,
        };

        regWrite32(VIRTIO_REG_QUEUE_SEL, index);
        regWrite32(VIRTIO_REG_QUEUE_NUM, VIRTQ_ENTRY_NUM);
        regWrite32(VIRTIO_REG_QUEUE_PFN, vq_paddr / PAGE_SIZE);

        return vq;
    }

    fn virtqKick(self: *VirtioBlk, desc_index: u16) void {
        const vq = self.request_vq;
        vq.avail.ring[vq.avail.index % VIRTQ_ENTRY_NUM] = desc_index;
        vq.avail.index +%= 1;

        asm volatile ("fence" ::: .{ .memory = true });

        regWrite32(VIRTIO_REG_QUEUE_NOTIFY, vq.queue_index);
        // Increment last_used_index here (matches C virtq_kick), so that
        // virtqIsBusy() correctly sees the device as busy until it completes.
        vq.last_used_index +%= 1;
    }

    fn virtqIsBusy(self: *VirtioBlk) bool {
        // Must be a volatile read: the device updates used.index asynchronously.
        const used_index_ptr: *volatile u16 = &self.request_vq.used.index;
        return self.request_vq.last_used_index != used_index_ptr.*;
    }

    fn validateSector(self: *VirtioBlk, sector: usize) VirtIoError!void {
        if (sector * SECTOR_SIZE >= self.capacity) {
            return error.SectorOutOfRange;
        }
    }

    fn performIo(self: *VirtioBlk, req_type: VirtIoBlkReqType) VirtIoError!void {
        const req = self.req;
        req.type = @intFromEnum(req_type);
        req.reserved = 0;

        const vq = self.request_vq;
        const req_paddr = self.req_paddr;

        const data_offset = @offsetOf(VirtioBlkReq, "data");
        const status_offset = @offsetOf(VirtioBlkReq, "status");

        log.debug("virtio", "performIo type={} sector={} req_paddr={x}", .{ @intFromEnum(req_type), req.sector, req_paddr });

        vq.descs[0].addr = req_paddr;
        vq.descs[0].len = @sizeOf(u32) * 2 + @sizeOf(u64);
        vq.descs[0].flags = VIRTQ_DESC_F_NEXT;
        vq.descs[0].next = 1;

        vq.descs[1].addr = req_paddr + data_offset;
        vq.descs[1].len = SECTOR_SIZE;

        switch (req_type) {
            .read => {
                vq.descs[1].flags = VIRTQ_DESC_F_NEXT | VIRTQ_DESC_F_WRITE;
            },
            .write => {
                vq.descs[1].flags = VIRTQ_DESC_F_NEXT;
            },
        }
        vq.descs[1].next = 2;

        vq.descs[2].addr = req_paddr + status_offset;
        vq.descs[2].len = @sizeOf(u8);
        vq.descs[2].flags = VIRTQ_DESC_F_WRITE;
        vq.descs[2].next = 0;

        log.debug("virtio", "kick: avail.index={} last_used={} used.index={}", .{
            vq.avail.index,
            vq.last_used_index,
            vq.used.index,
        });

        self.virtqKick(0);

        log.debug("virtio", "waiting: last_used={} used.index={}", .{
            vq.last_used_index,
            vq.used.index,
        });

        while (self.virtqIsBusy()) {}

        log.debug("virtio", "done: status={} last_used={} used.index={}", .{
            req.status,
            vq.last_used_index,
            vq.used.index,
        });

        if (req.status != 0) {
            log.err("virtio", "IO error: status={}", .{req.status});
            return error.IoError;
        }
    }

    pub fn init() VirtIoError!VirtioBlk {
        if (regRead32(VIRTIO_REG_MAGIC) != VIRTIO_MAGIC) {
            log.err("virtio", "bad magic {x}", .{regRead32(VIRTIO_REG_MAGIC)});
            return error.BadMagic;
        }
        if (regRead32(VIRTIO_REG_VERSION) != 1) {
            return error.BadVersion;
        }
        if (regRead32(VIRTIO_REG_DEVICE_ID) != VIRTIO_DEVICE_BLK) {
            return error.NotBlockDevice;
        }

        regWrite32(VIRTIO_REG_DEVICE_STATUS, 0);
        regFetchAndOr32(VIRTIO_REG_DEVICE_STATUS, VIRTIO_STATUS_ACK);
        regFetchAndOr32(VIRTIO_REG_DEVICE_STATUS, VIRTIO_STATUS_DRIVER);

        regWrite32(VIRTIO_REG_PAGE_SIZE, PAGE_SIZE);

        const request_vq = virtqInit(0);

        regWrite32(VIRTIO_REG_DEVICE_STATUS, VIRTIO_STATUS_DRIVER_OK);

        const capacity = regRead64(VIRTIO_REG_DEVICE_CONFIG) * SECTOR_SIZE;

        const req_pages = math.alignUp(@sizeOf(VirtioBlkReq), PAGE_SIZE) / PAGE_SIZE;
        const req_paddr = allocator.allocPages(req_pages);
        const req: *VirtioBlkReq = @ptrFromInt(req_paddr);

        log.info("virtio", "capacity: {} bytes", .{capacity});

        return .{
            .request_vq = request_vq,
            .req = req,
            .req_paddr = req_paddr,
            .capacity = capacity,
        };
    }

    pub fn readSector(self: *VirtioBlk, buf: [*]u8, sector: usize) VirtIoError!void {
        try self.validateSector(sector);
        log.debug("virtio", "readSector sector={}", .{sector});

        const req = self.req;
        req.sector = sector;

        try self.performIo(.read);

        @memcpy(buf[0..SECTOR_SIZE], self.req.data[0..SECTOR_SIZE]);
        log.debug("virtio", "readSector sector={} done", .{sector});
    }

    pub fn writeSector(self: *VirtioBlk, buf: [*]u8, sector: usize) VirtIoError!void {
        try self.validateSector(sector);
        log.debug("virtio", "writeSector sector={}", .{sector});

        const req = self.req;
        req.sector = sector;

        @memcpy(self.req.data[0..SECTOR_SIZE], buf[0..SECTOR_SIZE]);

        try self.performIo(.write);
        log.debug("virtio", "writeSector sector={} done", .{sector});
    }
};
