# lib — Agent Guidance

- Logger uses comptime level checks; disabled-level calls compile to nothing (zero overhead).
- `panic` calls SBI shutdown; do not import into user-space code.
- Math functions are comptime-friendly (`alignUp` uses arithmetic, not loops).
