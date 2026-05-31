# kernel — Agent Guidance

- `syscall.zig` dispatches by syscall number; add new cases in `dispatch()`.
- Always validate user-provided addresses with `validateUserPtr()` before dereferencing.
- `trap.zig` panics on unhandled traps — extend the switch cases for new exception/interrupt types.
- The root `Context` in `context.zig` is a singleton; access via `Context.current()`.
