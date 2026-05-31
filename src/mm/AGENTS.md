# mm — Agent Guidance

- The bump allocator only supports allocation; calling code must not assume free is available.
- `layout.zig` constants are imported across the kernel; changing them affects process creation, paging, and the linker script.
- `allocator.allocPages` returns physical addresses, not pointers.
