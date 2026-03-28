---
name: task-workflow
description: Manage tasks with Bridge (br) — a dependency-aware global task manager
---

# Bridge Task Workflow

Bridge (`br`) is a global task manager that persists across repos and sessions. Tasks form a dependency DAG — use `br ready` to see what's unblocked.

## CLI Reference

```
br add <title> [-p 0-4] [-t tag] [-d "description"]   # Create task (auto-tags repo)
br ls [-s status] [-t tag] [-j]                        # List tasks (default: open)
br ready [-t tag] [-j]                                 # Unblocked tasks only
br show <id>                                           # Full task detail
br note <id> "text"                                    # Add note to task
br edit <id> [--title T] [--desc D] [-p N] [-s status] # Edit fields
br start <id>                                          # Set status → in_progress
br done <id>                                           # Set status → done
br cancel <id>                                         # Set status → cancelled
br rm <id>                                             # Delete task
br dep add <blocker> <blocked>                         # A blocks B
br dep rm <blocker> <blocked>                          # Remove dependency
br blocked                                             # Show blocked tasks + blockers
br tag <id> <tag> [tag...]                             # Add tags
br untag <id> <tag> [tag...]                           # Remove tags
br tags                                                # List all tags with counts
br stats                                               # Task counts by status
```

## Workflow

1. **Check what's ready**: `br ready`
2. **Pick a task**: `br start <id>`
3. **Do the work**
4. **Complete**: `br done <id>`
5. **Check next**: `br ready`

## Conventions

- **IDs**: ULIDs — use first 8+ chars as prefix (enough for uniqueness)
- **Priorities**: P0 (critical) → P4 (lowest). Default P2.
- **Tags**: `namespace:value` convention. Auto-tags `repo:<name>` on add.
- **Statuses**: open → in_progress → done/cancelled
- **Dependencies**: "A blocks B" means B can't start until A is done/cancelled
- **Ready**: open + all blockers are done/cancelled
- `-j` flag on any list command outputs raw JSON

## Planning Pattern

When breaking down work:
1. Create tasks for each step: `br add "step description" -p N`
2. Wire dependencies: `br dep add <earlier> <later>`
3. Verify: `br ready` shows only the starting tasks
4. Work through: start → do → done → next ready
