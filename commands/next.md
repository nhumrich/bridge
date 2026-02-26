---
name: next
description: Pick up the next ready task from Bridge
---

Run `br ready` to see unblocked tasks, then start the highest priority one.

If there are ready tasks:
1. Run `br ready`
2. Pick the top task (highest priority)
3. Run `br start <id>` to claim it
4. Begin implementation

If no tasks are ready:
1. Run `br blocked` to see what's stuck
2. Check if any blockers can be resolved
3. If truly stuck, ask the user what to work on next
