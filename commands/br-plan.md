---
description: Break down work into Bridge tasks with dependencies for the current repo.
---

Break down work into Bridge tasks with dependencies for the current repo.

The user's input after `/br:plan` describes what they want to accomplish.

First, determine the current repo by running `git rev-parse --show-toplevel` and extracting the basename. All created tasks should include `-t repo:<basename>`.

A multi-task plan is a body of work — create a **project** to group it, then attach every task to that project with `--project`. The project gives later agents shared context (title + description) when they pick up a member task, and lets you scope `br ls`/`br ready` to just this effort. Projects are orthogonal to `repo:` tags — keep tagging tasks with `repo:<basename>` too.

1. Create a project for the effort: `br project add "<short project name>" -d "<overall goal and context>"`
2. Analyze the work and break it into discrete, completable steps
3. For each step, run: `br add "<short title>" -d "<implementation details and context>" -p N [-t tag ...] -t repo:<basename> --project "<project name>"`
4. Wire dependencies where order matters: `br dep add <earlier-id> <later-id>`
5. Show the final plan: `br project show "<project name>"` and `br ready --project "<project name>"`

Guidelines:
- Keep tasks small enough to complete in one session
- Titles must be short summaries (max 120 chars) — put specs, file paths, and details in `-d`
- Use priorities for importance, deps for ordering
- 3-8 tasks is usually the right granularity
- For a single throwaway task, a project is overkill — skip it. Use one for any real multi-task effort.
- Ask clarifying questions if the scope is unclear
