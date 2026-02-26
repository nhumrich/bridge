Pick up the next ready task from Bridge for the current repo.

First, determine the current repo by running `git rev-parse --show-toplevel` and extracting the basename. Use this as the tag filter: `repo:<basename>`.

1. Run `br ready -t repo:<basename>` to see unblocked tasks for this project
2. If there are ready tasks:
   - Pick the top one (highest priority)
   - Run `br start <id>`
   - Tell the user what you're working on and begin implementation
3. If no tasks are ready:
   - Run `br blocked` and look for tasks tagged `repo:<basename>`
   - Report to the user and ask how to proceed

If not in a git repo, run `br ready` without a tag filter and let the user choose.
