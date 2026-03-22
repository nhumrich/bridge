## Task Management
We track work in Bridge (`br`) — a global task manager. Run `br --help` to see commands.

### br Workflow
  1. Check what's ready: `br ready`
  2. Add tasks: `br add "task description" -p 0` (0=highest priority)
  3. Add dependencies: `br dep add <blocker> <blocked>` (first arg blocks second)
  4. Start work: `br start <id>`
  5. Complete work: `br close <id>`

### br Best Practices
  - Break down complex tasks into multiple issues with dependencies
  - Use `br ready` to see unblocked work before starting
  - Tags use `namespace:value` convention (e.g., `repo:bridge`, `feature`, `bug`)
  - Use `-t tag` to filter by tag
  - Use `br show <id>` for task details
