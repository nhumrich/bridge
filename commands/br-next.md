Pick the best ready tasks (up to 5) and work them in parallel.

## 1. Determine context

Run `git rev-parse --show-toplevel` to get the repo basename. If in a git repo, use `repo:<basename>` as tag filter.

## 2. Fetch ready tasks

- In a repo: `br graph -t repo:<basename>`
- Not in a repo: `br graph`
- Scoped to a project: if the user names a project (or is clearly working one), add `--project <name>` to scope selection to that body of work, e.g. `br graph --project <name>`

Reading the output:

- Top-level rows (no tree glyph) are the ready tasks, already sorted P0→P4 then oldest-first.
- Indented rows are blocked by the task above them. `[ ]` open, `[~]` in_progress, `[!]` blocked.
- A root with children is high-leverage — closing it unblocks them.
- Titles are truncated at 72 chars. If a candidate's title is cut off, run `br show <id>` for the full text.

If no tasks are ready, run `br blocked --json`, report what's stuck, and ask the user how to proceed.

## 3. Rank and select (up to 5)

From the ready list, pick the best tasks to work on now:

1. **Priority first** — P0 before P1 before P2, etc.
2. **Repo relevance** — prefer tasks tagged with current repo
3. **Unblocks others** — prefer roots that have indented children under them, and more children over fewer
4. **Skip vague/unclear tasks** — if a task title is ambiguous, deprioritize it

Create an implementation plan:
* Select up to 5 tasks. If only 1 is ready, just pick it.
* Identify which can be done in true parallel (e.g. multiple agents, parallel file edits)
* Note any logical sequencing needed


## 4. Start and execute

- Run `br start <id>` for each selected task
- If 1 task: begin implementation directly
- If 2+ tasks: use the `dispatching-parallel-agents` skill to work them in parallel (each agent gets a worktree)
- Tell the user which tasks you're picking up and why
- execute the plan from above
- As each task is completed:
  * verify the implementation works
  * run `/code-review --fix` on the solution
  * close the task: `br close <id>`
- show the final summary

## Best practices:
- Use parallel file edits when tasks touch different files
- Update br task status immediately before starting and after completing each task
- Add notes when discovering important context: `br note <id> "finding"`
- If a task fails, leave it in_progress and report the issue to the user, and also note it by using `br note <id> "what went wrong"`
