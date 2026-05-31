# sched — Round-Robin Cooperative Scheduler

Simple round-robin scheduler. Owns the current and idle process pointers but not the process table.

- `Scheduler.yield` — selects the next runnable process, switches address space, and swaps context.
- Falls back to idle process when no user process is runnable.
