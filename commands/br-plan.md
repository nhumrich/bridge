Break down work into Bridge tasks with dependencies for the current repo.

The user's input after `/br:plan` describes what they want to accomplish.

First, determine the current repo by running `git rev-parse --show-toplevel` and extracting the basename. All created tasks should include `-t repo:<basename>`.

1. Analyze the work and break it into discrete, completable steps
2. For each step, run: `br add "<step>" -p N [-t tag ...] -t repo:<basename>`
3. Wire dependencies where order matters: `br dep add <earlier-id> <later-id>`
4. Show the final plan: `br ls -t repo:<basename>` and `br ready -t repo:<basename>`

Guidelines:
- Keep tasks small enough to complete in one session
- Use priorities for importance, deps for ordering
- 3-8 tasks is usually the right granularity
- Ask clarifying questions if the scope is unclear
