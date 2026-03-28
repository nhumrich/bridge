Add a note to a Bridge task. The user's input after `/br:note` is the task reference and note content.

## 1. Parse input

- If the input starts with what looks like a task ID prefix (8+ alphanumeric chars), split it from the rest as the note content.
- Otherwise, run `br ls -j` to find a matching task by title from the description.
- If no task is identified, check for a task currently in_progress for this repo: `br ls -s in_progress -t repo:<basename> -j`

## 2. Determine repo context

Run `git rev-parse --show-toplevel` to get the repo basename for tag filtering.

## 3. Add the note

Run: `br note <id> "<note content>"`

## Examples

- `/br:note 01J3ABCD found the root cause — it's a race condition in the worker pool`
- `/br:note login bug: the OAuth token isn't being refreshed properly`
