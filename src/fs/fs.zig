const std = @import("std");
const virtio = @import("virtio");
const math = @import("math");
const log = @import("logger");

const SECTOR_SIZE: usize = 512;
const FILES_MAX: usize = 2;
// Compute disk size exactly like the C reference: align_up(sizeof(struct file) * FILES_MAX, SECTOR_SIZE)
const DISK_SIZE: usize = math.alignUp(@sizeOf(File) * FILES_MAX, SECTOR_SIZE);

pub const File = struct {
    in_use: bool,
    name: [100]u8,
    name_len: usize,
    data: [1024]u8,
    size: usize,
};

const TarHeader = extern struct {
    name: [100]u8,
    mode: [8]u8,
    uid: [8]u8,
    gid: [8]u8,
    size: [12]u8,
    mtime: [12]u8,
    checksum: [8]u8,
    typeflag: u8,
    linkname: [100]u8,
    magic: [6]u8,
    version: [2]u8,
    uname: [32]u8,
    gname: [32]u8,
    devmajor: [8]u8,
    devminor: [8]u8,
    prefix: [155]u8,
    _pad: [12]u8,
};

var blk: *virtio.VirtioBlk = undefined;
var files: [FILES_MAX]File = undefined;
var disk: [DISK_SIZE]u8 = undefined;

fn oct2int(s: []const u8) usize {
    var n: usize = 0;
    for (s) |c| {
        if (c < '0' or c > '7') break;
        n = n * 8 + (c - '0');
    }
    return n;
}

fn setName(dst: *[100]u8, src: []const u8) void {
    @memset(dst[0..], 0);
    const len = @min(src.len, 100);
    @memcpy(dst[0..len], src[0..len]);
}

pub fn init(virtio_blk: *virtio.VirtioBlk) void {
    blk = virtio_blk;

    // Read all disk sectors into the disk buffer (matches C reference).
    log.debug("fs", "reading {} sectors ({} bytes)", .{ DISK_SIZE / SECTOR_SIZE, DISK_SIZE });
    for (0..DISK_SIZE / SECTOR_SIZE) |sector| {
        log.debug("fs", "readSector {}", .{sector});
        blk.readSector(disk[sector * SECTOR_SIZE ..].ptr, sector) catch |err| {
            log.err("fs", "readSector {} failed: {}", .{ sector, err });
        };
    }

    var off: usize = 0;
    var file_i: usize = 0;
    while (file_i < FILES_MAX) : (file_i += 1) {
        if (off >= DISK_SIZE) break;

        const header: *TarHeader = @ptrCast(@alignCast(&disk[off]));

        if (header.name[0] == 0) break;

        if (!std.mem.eql(u8, header.magic[0..5], "ustar")) {
            return;
        }

        const filesz = oct2int(header.size[0..11]);

        const file: *File = &files[file_i];
        file.in_use = true;

        const raw_name = std.mem.span(@as([*:0]const u8, @ptrCast(&header.name)));
        const copy_len = @min(raw_name.len, 100);
        setName(&file.name, raw_name[0..copy_len]);
        file.name_len = copy_len;

        const data_off = off + 512;
        const copy_data_len = @min(filesz, file.data.len);
        @memcpy(file.data[0..copy_data_len], disk[data_off .. data_off + copy_data_len]);
        file.size = filesz;

        log.info("fs", "loaded '{s}' ({} bytes)", .{ raw_name[0..copy_len], filesz });

        off += 512 + math.alignUp(filesz, 512);
    }
}

pub fn lookup(filename: [*:0]const u8) ?*File {
    const name_slice = std.mem.span(filename);
    for (files[0..FILES_MAX]) |*file| {
        if (!file.in_use) continue;
        const file_name = std.mem.span(@as([*:0]const u8, @ptrCast(&file.name)));
        if (std.mem.eql(u8, file_name, name_slice)) {
            return file;
        }
    }
    return null;
}

pub fn create(filename: [*:0]const u8) ?*File {
    const name_slice = std.mem.span(filename);
    for (files[0..FILES_MAX]) |*file| {
        if (!file.in_use) {
            file.in_use = true;
            setName(&file.name, name_slice);
            file.name_len = name_slice.len;
            file.size = 0;
            return file;
        }
    }
    return null;
}

pub fn flush() void {
    log.debug("fs", "flush", .{});

    var off: usize = 0;
    for (files[0..FILES_MAX]) |*file| {
        if (!file.in_use) continue;

        const header: *TarHeader = @ptrCast(@alignCast(&disk[off]));
        @memset(@as([*]u8, @ptrCast(header))[0..512], 0);

        setName(&header.name, std.mem.span(@as([*:0]const u8, @ptrCast(&file.name))));
        @memcpy(header.mode[0..7], "0000644");
        @memcpy(header.uid[0..7], "0000000");
        @memcpy(header.gid[0..7], "0000000");

        // Format size as octal
        var sizebuf: [12]u8 = undefined;
        const size_str = std.fmt.bufPrint(&sizebuf, "{o}", .{file.size}) catch "0";
        @memcpy(header.size[0..size_str.len], size_str);

        @memcpy(header.mtime[0..11], "00000000000");
        @memcpy(header.checksum[0..8], "        ");
        header.typeflag = '0';
        header.magic = "ustar\x00".*;
        header.version = "00".*;

        @memcpy(disk[off + 512 .. off + 512 + file.size], file.data[0..file.size]);

        off += 512 + math.alignUp(file.size, 512);
        if (off >= DISK_SIZE) break;
    }

    // Write disk back to VirtIO
    for (0..DISK_SIZE / SECTOR_SIZE) |sector| {
        blk.writeSector(disk[sector * SECTOR_SIZE ..].ptr, sector) catch |err| {
            log.err("fs", "flush writeSector {} failed: {}", .{ sector, err });
        };
    }
}
