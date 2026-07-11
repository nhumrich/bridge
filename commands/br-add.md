Add a task to Bridge. The user's input after `/br:add` is the task description.

Parse the user's intent to determine:
- **title**: a short summary of the task (max 120 chars, required)
- **description**: implementation details, specs, context, or acceptance criteria (use `-d`)
- **priority**: if they mention urgency/importance, map to -p 0-4 (0=highest). If you don't pass -p, the task defaults to P2 (normal) — the created output will show `Priority: P2 (defaulted)`. If P2 is wrong for this task, reprioritize with `br edit <id> -p N`.
- **tags**: if they mention categories, components, or labels, pass as -t flags
- **project**: if they reference an existing project (a named body of work), pass `--project <name>` to attach the task to it

**Important**: Titles must be short, human-readable summaries. Do NOT put implementation details, file paths, code snippets, or full specs in the title. Use `-d "..."` for all details beyond the summary.

Auto-tagging: determine the current repo by running `git rev-parse --show-toplevel` and extracting the basename. If in a git repo, always include `-t repo:<basename>` so the task is associated with this project.

Then run `br add "<title>" [-d "<description>"] [-p N] [-t tag ...] [-t repo:<repo>] [--project <name>]` and show the result.

Examples:
- `/br:add fix the login bug` → `br add "Fix the login bug" -t repo:myapp`
- `/br:add urgent: deploy hotfix` → `br add "Deploy hotfix" -p 0 -t repo:myapp`
- `/br:add add caching layer #backend #perf` → `br add "Add caching layer" -d "Add Redis caching to the API response path for frequently accessed endpoints" -t backend -t perf -t repo:myapp`
