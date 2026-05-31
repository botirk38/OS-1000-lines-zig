# fs — Agent Guidance

- Filesystem init and flush now return `!void`; callers must handle I/O errors.
- Tar checksums are computed in `computeTarChecksum` during `flush`.
- Bounds: `FILES_MAX = 2`, file data = 1024 bytes, filename = 100 bytes.
- The disk buffer is sized to exactly fit the file array; changing file limits requires recalculating `DISK_SIZE`.
