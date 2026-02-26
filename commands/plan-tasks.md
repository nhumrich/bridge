---
name: plan-tasks
description: Break down a plan into Bridge tasks with dependencies
---

Convert the current plan or requested work into Bridge tasks:

1. **Identify steps** — break the work into discrete, completable tasks
2. **Create tasks** — `br add "step" -p N -t tag` for each
3. **Wire dependencies** — `br dep add <earlier> <later>` where order matters
4. **Verify** — `br ready` should show only starting tasks, `br blocked` shows the rest
5. **Report** — show the user `br ls` and `br ready` output

Guidelines:
- Keep tasks small enough to complete in one session
- Use priorities to indicate importance, not order (deps handle order)
- Tag with relevant context (feature name, component, etc.)
- Don't over-decompose — 3-8 tasks is usually right
