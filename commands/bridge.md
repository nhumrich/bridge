## Task Management
We track work in Bridge (`br`) — a global task manager. Run `br --help` to see commands.

### br Workflow
  1. Check what's ready: `br ready`
  2. Add tasks: `br add "task description" -p 0` (0=highest priority)
  3. Add dependencies: `br dep add <blocker> <blocked>` (first arg blocks second)
  4. Start work: `br start <id>`
  5. Add notes: `br note <id> "context or findings"`
  6. Complete work: `br close <id>`

### br Best Practices
  - Break down complex tasks into multiple issues with dependencies
  - Use `br ready` to see unblocked work before starting
  - Tags use `namespace:value` convention (e.g., `repo:bridge`, `feature`, `bug`)
  - Use `-t tag` to filter by tag
  - Use `br show <id>` for task details

### Projects
A project is a first-class tracker grouping a body of work — its own title, description, and status — orthogonal to tags (a task can belong to a project AND carry `repo:` tags). A task belongs to at most one project. Project status (`active`/`done`/`archived`) is manual; it never auto-closes from member tasks.
  - Create: `br project add "<name>" -d "<description>"`
  - Assign on create: `br add "<title>" --project <name>`
  - Assign existing task: `br edit <id> --project <name>` (clear with `--no-project`)
  - Inspect: `br project ls`, `br project show <name>` (lists members + progress)
  - Filter any read command by project: `br ls --project <name>`, `br ready --project <name>`
  - Reference a project by its unique name or an ID prefix
