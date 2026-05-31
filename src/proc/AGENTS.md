# proc — Agent Guidance

- `Process` state machine: `.unused` → `.runnable` → `.unused`.
- `create` maps all kernel RAM and the VirtIO MMIO region for every new process (identity-mapped supervisor pages).
- User image pages are allocated and mapped with user flags; kernel pages are supervisor-only.
- The idle process (pid=0) has no user image and is always runnable.
