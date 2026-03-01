# `br ls --closed` / `--all` Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `--closed` and `--all` flags to `br ls` so users can view closed/all tasks.

**Architecture:** Add two flags to the `ls`/`list` arg parser. Modify `cmd_ls` to accept these flags and adjust the SQL WHERE clause accordingly. `--closed` shows only terminal tasks (done/cancelled), `--all` removes status filtering entirely. Existing `-s`, `-t`, `-j` all still work.

**Tech Stack:** Pact, std.args, SQLite

---

### Task 1: Add `--closed` and `--all` flags to arg parser

**Files:**
- Modify: `src/main.pact:39-45` (ls/list command definitions)
- Modify: `src/main.pact:138-141` (ls dispatch)

**Step 1: Add flags to parser**

In `build_parser()`, add flags for both `ls` and `list`:

```pact
p = command_add_flag(p, "ls", "--closed", "-c", "Show closed tasks")
p = command_add_flag(p, "ls", "--all", "-a", "Show all tasks")
p = command_add_flag(p, "list", "--closed", "-c", "Show closed tasks")
p = command_add_flag(p, "list", "--all", "-a", "Show all tasks")
```

**Step 2: Pass flags to cmd_ls**

In the dispatch block, extract and pass flags:

```pact
} else if cmd == "ls" || cmd == "list" {
    let status_filter = args_get(a, "s")
    let tag_filter = args_get(a, "t")
    let show_closed = args_has(a, "closed")
    let show_all = args_has(a, "all")
    cmd_ls(status_filter, tag_filter, json_mode, show_closed, show_all)
```

**Step 3: Build and verify it compiles**

Run: `pact build src/main.pact`
Expected: Compile error (cmd_ls signature mismatch) — that's fine, Task 2 fixes it.

### Task 2: Update `cmd_ls` to handle new flags

**Files:**
- Modify: `src/commands.pact:138-165` (cmd_ls function)

**Step 1: Update cmd_ls signature and WHERE logic**

```pact
pub fn cmd_ls(status_filter: Str, tag_filter: Str, json_mode: Bool, show_closed: Bool, show_all: Bool) {
    let mut where_parts: List[Str] = []
    if !status_filter.is_empty() {
        let sf = sql_escape(status_filter)
        where_parts.push("t.status = '{sf}'")
    } else if show_closed {
        where_parts.push("t.status IN ('done', 'cancelled')")
    } else if show_all {
        // no status filter
    } else {
        where_parts.push("t.status NOT IN ('done', 'cancelled')")
    }
    // rest unchanged
```

**Step 2: Build and test**

Run: `pact build src/main.pact`
Expected: Success

**Step 3: Manual smoke test**

```
br ls              # open tasks only (existing behavior)
br ls --closed     # done/cancelled only
br ls --all        # everything
br ls --closed -t repo:bridge   # closed + tag filter
br ls -a           # short flag for --all
br ls -c           # short flag for --closed
```

**Step 4: Commit**

```bash
git add src/main.pact src/commands.pact
git commit -m "Add --closed and --all flags to br ls"
```
