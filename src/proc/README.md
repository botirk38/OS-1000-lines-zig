# proc — Process Structures

Defines the `Process` type and process `Table`.

- `Process` — pid, state, saved stack pointer, kernel stack, page table pointer.
- `Table` — fixed array of `PROCS_MAX` (8) processes; `create`, `createIdle`, `createUser`.
- On exit, process slot resets to `.unused` for reuse. Page memory is leaked (bump allocator limitation).
