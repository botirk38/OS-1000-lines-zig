# fs — Tar-Based Filesystem

Reads and writes a simple tar-format filesystem backed by the VirtIO block device.

- `init` — reads disk sectors, parses tar headers into a file array.
- `lookup` — find a file by name.
- `create` — add a new file entry.
- `flush` — serializes files back into tar format and writes to disk.
