# sched — Agent Guidance

- The scheduler iterates through the process table starting from the next slot after `current_pid`.
- Changing the scheduling policy: implement a new module matching the `Scheduler` struct interface.
- `yield` calls `arch.Context.activateAddressSpace` then `arch.Context.swap` — both must succeed atomically for correct context switching.
