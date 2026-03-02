import db
import ulid
import display
import std.json

fn list_contains(items: List[Str], target: Str) -> Bool {
    let mut i = 0
    while i < items.len() {
        if (items.get(i) ?? "") == target {
            return true
        }
        i = i + 1
    }
    false
}

fn sql_escape(s: Str) -> Str {
    s.replace("'", "''")
}

fn is_empty_json(s: Str) -> Bool {
    s.is_empty() || s == "[]"
}

fn jstr(row: Int, field: Str) -> Str {
    let node = json_get(row, field)
    if node == -1 { return "" }
    if json_type(node) == JSON_NULL { return "" }
    json_as_str(node)
}

fn jint(row: Int, field: Str) -> Int {
    let node = json_get(row, field)
    if node == -1 { return 0 }
    if json_type(node) == JSON_NULL { return 0 }
    json_as_int(node)
}

pub fn resolve_id(prefix: Str) -> Str {
    let escaped = sql_escape(prefix.to_lower())
    let result = db_query("SELECT id FROM tasks WHERE id LIKE '{escaped}%%'")
    if is_empty_json(result) {
        io.eprintln("No task matches prefix: {prefix}")
        exit(1)
    }
    json_clear()
    let root = json_parse(result)
    if json_len(root) > 1 {
        io.eprintln("Ambiguous prefix '{prefix}', multiple matches")
        exit(1)
    }
    let row = json_at(root, 0)
    jstr(row, "id")
}

fn tags_for_task(task_id: Str) -> Str {
    let result = db_query("SELECT tag FROM tags WHERE task_id = '{task_id}'")
    if is_empty_json(result) {
        return ""
    }
    let mut tags: List[Str] = []
    json_clear()
    let root = json_parse(result)
    let count = json_len(root)
    let mut i = 0
    while i < count {
        let row = json_at(root, i)
        let tag = jstr(row, "tag")
        if !tag.is_empty() {
            tags.push(tag)
        }
        i = i + 1
    }
    tags.join(", ")
}

fn parse_rows_as_task_lines(result: Str) {
    json_clear()
    let root = json_parse(result)
    let count = json_len(root)
    let mut i = 0
    while i < count {
        let row = json_at(root, i)
        let id = jstr(row, "id")
        let title = jstr(row, "title")
        let priority = jint(row, "priority")
        let status = jstr(row, "status")
        let tags = jstr(row, "tags")
        io.println(format_task_line(id, title, priority, status, tags))
        i = i + 1
    }
}

// --- Activity Logging ---

fn log_activity(task_id: Str, action: Str, session_id: Str) {
    let project_path = get_env("PWD") ?? ""
    let sid = get_env("BR_SESSION_ID") ?? session_id
    let s = sql_escape(sid)
    let p = sql_escape(project_path)
    db_exec("INSERT INTO activity_log (task_id, action, session_id, project_path) VALUES ('{task_id}', '{action}', '{s}', '{p}')")
}

// --- CRUD Commands ---

pub fn cmd_add(title: Str, description: Str, priority: Int, tag_list: List[Str], session_id: Str) {
    let id = generate_id()
    let t = sql_escape(title)
    let d = sql_escape(description)
    db_exec("INSERT INTO tasks (id, title, description, priority) VALUES ('{id}', '{t}', '{d}', {priority})")

    for tag in tag_list {
        let tg = sql_escape(tag)
        db_exec("INSERT OR IGNORE INTO tags (task_id, tag) VALUES ('{id}', '{tg}')")
    }

    log_activity(id, "created", session_id)
    io.println("Created: {short_id(id)}  {title}")
}

pub fn cmd_ls(status_filter: Str, tag_filter: Str, json_mode: Bool, show_closed: Bool, show_all: Bool) {
    let mut where_parts: List[Str] = []
    if !status_filter.is_empty() {
        let sf = sql_escape(status_filter)
        where_parts.push("t.status = '{sf}'")
    } else if show_closed {
        where_parts.push("t.status IN ('done', 'cancelled')")
    } else if !show_all {
        where_parts.push("t.status NOT IN ('done', 'cancelled')")
    }
    if !tag_filter.is_empty() {
        let tf = sql_escape(tag_filter)
        where_parts.push("EXISTS (SELECT 1 FROM tags tg WHERE tg.task_id = t.id AND tg.tag = '{tf}')")
    }
    let where_clause = if where_parts.len() == 0 { "" } else { " WHERE {where_parts.join(" AND ")}" }
    let sql = "SELECT t.id, t.title, t.priority, t.status, COALESCE(GROUP_CONCAT(tg.tag, ', '), '') as tags FROM tasks t LEFT JOIN tags tg ON tg.task_id = t.id{where_clause} GROUP BY t.id ORDER BY t.priority ASC, t.created_at ASC"
    let result = db_query(sql)

    if json_mode {
        io.println(result)
        return
    }

    if is_empty_json(result) {
        io.println("No tasks found.")
        return
    }

    parse_rows_as_task_lines(result)
}

pub fn cmd_show(id_prefix: Str, json_mode: Bool) {
    let id = resolve_id(id_prefix)
    let result = db_query("SELECT * FROM tasks WHERE id = '{id}'")

    if json_mode {
        io.println(result)
        return
    }

    json_clear()
    let root = json_parse(result)
    let row = json_at(root, 0)
    let title = jstr(row, "title")
    let description = jstr(row, "description")
    let status = jstr(row, "status")
    let priority = jint(row, "priority")
    let created_at = jstr(row, "created_at")
    let updated_at = jstr(row, "updated_at")
    let closed_at = jstr(row, "closed_at")
    let tags = tags_for_task(id)

    let blocks_result = db_query("SELECT blocked_id FROM deps WHERE blocker_id = '{id}'")
    let mut blocks_list: List[Str] = []
    if !is_empty_json(blocks_result) {
        json_clear()
        let broot = json_parse(blocks_result)
        let bcount = json_len(broot)
        let mut bi = 0
        while bi < bcount {
            let brow = json_at(broot, bi)
            blocks_list.push(short_id(jstr(brow, "blocked_id")))
            bi = bi + 1
        }
    }

    let blocked_by_result = db_query("SELECT blocker_id FROM deps WHERE blocked_id = '{id}'")
    let mut blocked_by_list: List[Str] = []
    if !is_empty_json(blocked_by_result) {
        json_clear()
        let bbroot = json_parse(blocked_by_result)
        let bbcount = json_len(bbroot)
        let mut bbi = 0
        while bbi < bbcount {
            let bbrow = json_at(bbroot, bbi)
            blocked_by_list.push(short_id(jstr(bbrow, "blocker_id")))
            bbi = bbi + 1
        }
    }

    io.println(format_task_detail(id, title, description, status, priority, created_at, updated_at, closed_at, tags, blocks_list.join(", "), blocked_by_list.join(", ")))

    let activity_result = db_query("SELECT action, session_id, project_path, created_at FROM activity_log WHERE task_id = '{id}' ORDER BY created_at ASC")
    if !is_empty_json(activity_result) {
        io.println("  Activity:")
        json_clear()
        let aroot = json_parse(activity_result)
        let acount = json_len(aroot)
        let mut ai = 0
        while ai < acount {
            let ar = json_at(aroot, ai)
            let aaction = jstr(ar, "action")
            let asession = jstr(ar, "session_id")
            let apath = jstr(ar, "project_path")
            let aat = jstr(ar, "created_at")
            io.println(format_activity_line(aaction, asession, apath, aat))
            ai = ai + 1
        }
    }
}

pub fn cmd_edit(id_prefix: Str, title: Str, description: Str, priority: Int, status: Str, append: Bool) {
    let id = resolve_id(id_prefix)
    let mut sets: List[Str] = []
    if !title.is_empty() {
        sets.push("title = '{sql_escape(title)}'")
    }
    if !description.is_empty() {
        if append {
            sets.push("description = description || '\n' || '{sql_escape(description)}'")
        } else {
            sets.push("description = '{sql_escape(description)}'")
        }
    }
    if priority >= 0 {
        sets.push("priority = {priority}")
    }
    if !status.is_empty() {
        sets.push("status = '{sql_escape(status)}'")
        if status == "done" || status == "cancelled" {
            sets.push("closed_at = strftime('%Y-%m-%dT%H:%M:%SZ','now')")
        }
    }
    if sets.len() == 0 {
        io.eprintln("Nothing to update")
        exit(1)
    }
    sets.push("updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now')")
    let set_clause = sets.join(", ")
    db_exec("UPDATE tasks SET {set_clause} WHERE id = '{id}'")
    io.println("Updated: {short_id(id)}")
}

pub fn cmd_start(id_prefix: Str, session_id: Str) {
    let id = resolve_id(id_prefix)
    cmd_edit(id_prefix, "", "", -1, "in_progress", false)
    log_activity(id, "started", session_id)
}

pub fn cmd_stop(id_prefix: Str, session_id: Str) {
    let id = resolve_id(id_prefix)
    cmd_edit(id_prefix, "", "", -1, "open", false)
    log_activity(id, "stopped", session_id)
}

pub fn cmd_done(id_prefix: Str, session_id: Str) {
    let id = resolve_id(id_prefix)
    cmd_edit(id_prefix, "", "", -1, "done", false)
    log_activity(id, "closed", session_id)
}

pub fn cmd_cancel(id_prefix: Str, session_id: Str) {
    let id = resolve_id(id_prefix)
    cmd_edit(id_prefix, "", "", -1, "cancelled", false)
    log_activity(id, "cancelled", session_id)
}

pub fn cmd_rm(id_prefix: Str) {
    let id = resolve_id(id_prefix)
    db_exec("DELETE FROM tasks WHERE id = '{id}'")
    io.println("Deleted: {short_id(id)}")
}

// --- DAG Commands ---

pub fn cmd_ready(tag_filter: Str, json_mode: Bool) {
    let mut tag_clause = ""
    if !tag_filter.is_empty() {
        let tf = sql_escape(tag_filter)
        tag_clause = " AND EXISTS (SELECT 1 FROM tags tg WHERE tg.task_id = t.id AND tg.tag = '{tf}')"
    }
    let sql = "SELECT t.id, t.title, t.priority, t.status, COALESCE(GROUP_CONCAT(tg.tag, ', '), '') as tags FROM tasks t LEFT JOIN tags tg ON tg.task_id = t.id WHERE t.status = 'open' AND NOT EXISTS (SELECT 1 FROM deps d JOIN tasks blocker ON blocker.id = d.blocker_id WHERE d.blocked_id = t.id AND blocker.status NOT IN ('done', 'cancelled')){tag_clause} GROUP BY t.id ORDER BY t.priority ASC, t.created_at ASC"
    let result = db_query(sql)

    if json_mode {
        io.println(result)
        return
    }

    if is_empty_json(result) {
        io.println("No ready tasks.")
        return
    }

    parse_rows_as_task_lines(result)
}

fn has_cycle(from_id: Str, to_id: Str) -> Bool {
    let mut visited: List[Str] = []
    let mut stack: List[Str] = [to_id]

    while stack.len() > 0 {
        let current = stack.get(stack.len() - 1) ?? ""
        stack.pop()
        if current == from_id {
            return true
        }
        if list_contains(visited, current) {
            // already visited
        } else {
            visited.push(current)
            let deps_result = db_query("SELECT blocked_id FROM deps WHERE blocker_id = '{current}'")
            if !is_empty_json(deps_result) {
                json_clear()
                let droot = json_parse(deps_result)
                let dcount = json_len(droot)
                let mut di = 0
                while di < dcount {
                    let dr = json_at(droot, di)
                    let did = jstr(dr, "blocked_id")
                    if !did.is_empty() {
                        stack.push(did)
                    }
                    di = di + 1
                }
            }
        }
    }
    false
}

pub fn cmd_dep_add(blocker_prefix: Str, blocked_prefix: Str) {
    let blocker_id = resolve_id(blocker_prefix)
    let blocked_id = resolve_id(blocked_prefix)

    if blocker_id == blocked_id {
        io.eprintln("A task cannot block itself")
        exit(1)
    }

    if has_cycle(blocker_id, blocked_id) {
        io.eprintln("Cannot add dependency: would create a cycle")
        exit(1)
    }

    db_exec("INSERT OR IGNORE INTO deps (blocker_id, blocked_id) VALUES ('{blocker_id}', '{blocked_id}')")
    io.println("Added: {short_id(blocker_id)} blocks {short_id(blocked_id)}")
}

pub fn cmd_dep_rm(blocker_prefix: Str, blocked_prefix: Str) {
    let blocker_id = resolve_id(blocker_prefix)
    let blocked_id = resolve_id(blocked_prefix)
    db_exec("DELETE FROM deps WHERE blocker_id = '{blocker_id}' AND blocked_id = '{blocked_id}'")
    io.println("Removed: {short_id(blocker_id)} no longer blocks {short_id(blocked_id)}")
}

pub fn cmd_blocked(tag_filter: Str, json_mode: Bool) {
    let mut tag_clause = ""
    if !tag_filter.is_empty() {
        let tf = sql_escape(tag_filter)
        tag_clause = " AND EXISTS (SELECT 1 FROM tags tg2 WHERE tg2.task_id = t.id AND tg2.tag = '{tf}')"
    }
    let sql = "SELECT t.id, t.title, t.priority, t.status, COALESCE(GROUP_CONCAT(DISTINCT tg.tag), '') as tags, COALESCE(GROUP_CONCAT(DISTINCT d.blocker_id), '') as blockers FROM tasks t JOIN deps d ON d.blocked_id = t.id LEFT JOIN tags tg ON tg.task_id = t.id WHERE t.status NOT IN ('done', 'cancelled'){tag_clause} GROUP BY t.id ORDER BY t.priority ASC"
    let result = db_query(sql)

    if json_mode {
        io.println(result)
        return
    }

    if is_empty_json(result) {
        io.println("No blocked tasks.")
        return
    }

    json_clear()
    let root = json_parse(result)
    let num = json_len(root)
    let mut i = 0
    while i < num {
        let row = json_at(root, i)
        let id = jstr(row, "id")
        let title = jstr(row, "title")
        let priority = jint(row, "priority")
        let status = jstr(row, "status")
        let tags = jstr(row, "tags")
        let blockers = jstr(row, "blockers")
        let line = format_task_line(id, title, priority, status, tags)
        io.println("{line}  (blocked by: {blockers})")
        i = i + 1
    }
}

// --- Tag Commands ---

pub fn cmd_tag(id_prefix: Str, tags: List[Str]) {
    let id = resolve_id(id_prefix)
    for tag in tags {
        let tg = sql_escape(tag)
        db_exec("INSERT OR IGNORE INTO tags (task_id, tag) VALUES ('{id}', '{tg}')")
    }
    io.println("Tagged: {short_id(id)}")
}

pub fn cmd_untag(id_prefix: Str, tags: List[Str]) {
    let id = resolve_id(id_prefix)
    for tag in tags {
        let tg = sql_escape(tag)
        db_exec("DELETE FROM tags WHERE task_id = '{id}' AND tag = '{tg}'")
    }
    io.println("Untagged: {short_id(id)}")
}

pub fn cmd_tags() {
    let result = db_query("SELECT tag, COUNT(*) as count FROM tags GROUP BY tag ORDER BY count DESC, tag ASC")
    if is_empty_json(result) {
        io.println("No tags found.")
        return
    }
    json_clear()
    let root = json_parse(result)
    let num = json_len(root)
    let mut i = 0
    while i < num {
        let row = json_at(root, i)
        let tag = jstr(row, "tag")
        let cnt = jint(row, "count")
        io.println("  {tag}  ({cnt})")
        i = i + 1
    }
}

pub fn cmd_stats(tag_filter: Str) {
    let mut tag_join = ""
    let mut tag_where = ""
    if !tag_filter.is_empty() {
        let tf = sql_escape(tag_filter)
        tag_join = " JOIN tags tg ON tg.task_id = t.id"
        tag_where = " WHERE tg.tag = '{tf}'"
    }
    let result = db_query("SELECT t.status, COUNT(*) as count FROM tasks t{tag_join}{tag_where} GROUP BY t.status ORDER BY t.status")
    if is_empty_json(result) {
        io.println("No tasks.")
        return
    }
    io.println("Tasks:")
    json_clear()
    let root = json_parse(result)
    let num = json_len(root)
    let mut i = 0
    while i < num {
        let row = json_at(root, i)
        let status = jstr(row, "status")
        let cnt = jint(row, "count")
        io.println("  {status}: {cnt}")
        i = i + 1
    }
}

pub fn cmd_install() {
    let home = get_env("HOME") ?? "/tmp"
    let dest_dir = "{home}/.claude/commands"

    let result = process_run("mkdir", ["-p", dest_dir])
    if result.exit_code != 0 {
        io.eprintln("Failed to create {dest_dir}")
        exit(1)
    }

    const CMD_ADD = #embed("../commands/br-add.md")
    const CMD_CLOSE = #embed("../commands/br-close.md")
    const CMD_NEXT = #embed("../commands/br-next.md")
    const CMD_PLAN = #embed("../commands/br-plan.md")

    let names = ["br:add.md", "br:close.md", "br:next.md", "br:plan.md"]
    let contents = [CMD_ADD, CMD_CLOSE, CMD_NEXT, CMD_PLAN]

    let mut i = 0
    while i < names.len() {
        let name = names.get(i) ?? ""
        let content = contents.get(i) ?? ""
        let dest = path_join(dest_dir, name)
        write_file(dest, content)
        io.println("  Installed: {name}")
        i = i + 1
    }
    io.println("Installed {names.len()} commands to {dest_dir}")

    install_hook(home)
}

fn install_hook(home: Str) {
    let settings_path = "{home}/.claude/settings.json"
    let hook_cmd = "bash -c 'read input; sid=$(echo \"$input\" | sed -n '\\''s/.*\"session_id\":\"\\([^\"]*\\)\".*/\\1/p'\\''); [ -n \"$CLAUDE_ENV_FILE\" ] && [ -n \"$sid\" ] && echo \"export BR_SESSION_ID=$sid\" >> \"$CLAUDE_ENV_FILE\"'"

    json_clear()
    let mut root = -1
    if file_exists(settings_path) == 1 {
        let content = read_file(settings_path)
        if !content.trim().is_empty() {
            root = json_parse(content)
        }
    }
    if root == -1 {
        root = json_new_object()
    }

    let mut hooks_node = json_get(root, "hooks")
    if hooks_node == -1 {
        hooks_node = json_new_object()
        json_set(root, "hooks", hooks_node)
    }

    let mut ss_arr = json_get(hooks_node, "SessionStart")
    if ss_arr == -1 {
        ss_arr = json_new_array()
        json_set(hooks_node, "SessionStart", ss_arr)
    }

    let mut already_installed = false
    let mut idx = 0
    while idx < json_len(ss_arr) {
        let entry = json_at(ss_arr, idx)
        let inner_hooks = json_get(entry, "hooks")
        if inner_hooks != -1 {
            let mut j = 0
            while j < json_len(inner_hooks) {
                let h = json_at(inner_hooks, j)
                let cmd_node = json_get(h, "command")
                if cmd_node != -1 {
                    let cmd = json_as_str(cmd_node)
                    if cmd.contains("BR_SESSION_ID") {
                        already_installed = true
                    }
                }
                j = j + 1
            }
        }
        idx = idx + 1
    }

    if already_installed {
        io.println("  Hook: already installed")
        return
    }

    let hook_obj = json_new_object()
    json_set(hook_obj, "type", json_new_str("command"))
    json_set(hook_obj, "command", json_new_str(hook_cmd))

    let inner_arr = json_new_array()
    json_push(inner_arr, hook_obj)

    let entry = json_new_object()
    json_set(entry, "hooks", inner_arr)

    json_push(ss_arr, entry)

    write_file(settings_path, json_encode(root))
    io.println("  Hook: SessionStart (BR_SESSION_ID)")
}

pub fn cmd_uninstall() {
    let home = get_env("HOME") ?? "/tmp"
    let dest_dir = "{home}/.claude/commands"
    let names = ["br:add.md", "br:close.md", "br:next.md", "br:plan.md"]
    let mut removed = 0
    for name in names {
        let dest = path_join(dest_dir, name)
        if file_exists(dest) == 1 {
            process_run("rm", ["-f", dest])
            io.println("  Removed: {name}")
            removed = removed + 1
        }
    }
    if removed == 0 {
        io.println("Nothing to uninstall.")
    } else {
        io.println("Removed {removed} commands")
    }

    uninstall_hook(home)
}

fn uninstall_hook(home: Str) {
    let settings_path = "{home}/.claude/settings.json"
    if file_exists(settings_path) == 0 {
        return
    }

    let content = read_file(settings_path)
    if content.trim().is_empty() {
        return
    }

    json_clear()
    let root = json_parse(content)
    if root == -1 {
        return
    }

    let hooks_node = json_get(root, "hooks")
    if hooks_node == -1 {
        return
    }

    let ss_arr = json_get(hooks_node, "SessionStart")
    if ss_arr == -1 {
        return
    }

    let mut new_arr = json_new_array()
    let mut removed = false
    let mut idx = 0
    while idx < json_len(ss_arr) {
        let entry = json_at(ss_arr, idx)
        let mut is_ours = false
        let inner_hooks = json_get(entry, "hooks")
        if inner_hooks != -1 {
            let mut j = 0
            while j < json_len(inner_hooks) {
                let h = json_at(inner_hooks, j)
                let cmd_node = json_get(h, "command")
                if cmd_node != -1 {
                    let cmd = json_as_str(cmd_node)
                    if cmd.contains("BR_SESSION_ID") {
                        is_ours = true
                    }
                }
                j = j + 1
            }
        }
        if is_ours {
            removed = true
        } else {
            json_push(new_arr, entry)
        }
        idx = idx + 1
    }

    if removed {
        json_set(hooks_node, "SessionStart", new_arr)
        write_file(settings_path, json_encode(root))
        io.println("  Removed: SessionStart hook")
    }
}
