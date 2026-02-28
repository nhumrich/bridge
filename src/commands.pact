import db
import ulid
import display

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

fn lbrace() -> Str {
    "\{"
}

fn rbrace() -> Str {
    "\}"
}

fn strip_json_array(s: Str) -> Str {
    if s.len() < 2 { return s }
    s.slice(1, s.len() - 1)
}

fn split_json_rows(s: Str) -> List[Str] {
    let inner = strip_json_array(s)
    let sep = "{rbrace()},{lbrace()}"
    inner.split(sep)
}

fn clean_json_row(row: Str) -> Str {
    row.replace(lbrace(), "").replace(rbrace(), "")
}

fn is_empty_json(s: Str) -> Bool {
    s.is_empty() || s == "[]"
}

fn parse_json_field(json: Str, field: Str) -> Str {
    let key = "\"{field}\":"
    let idx = json.index_of(key)
    if idx < 0 {
        return ""
    }
    let after = json.slice(idx + key.len(), json.len())
    if after.starts_with("\"") {
        let rest = after.slice(1, after.len())
        let end = rest.index_of("\"")
        if end < 0 { return "" }
        return rest.slice(0, end)
    }
    if after.starts_with("null") {
        return ""
    }
    let mut end = after.index_of(",")
    if end < 0 {
        end = after.index_of(rbrace())
    }
    if end < 0 {
        return after
    }
    after.slice(0, end)
}

pub fn resolve_id(prefix: Str) -> Str {
    let escaped = sql_escape(prefix.to_lower())
    let result = db_query("SELECT id FROM tasks WHERE id LIKE '{escaped}%%'")
    if is_empty_json(result) {
        io.eprintln("No task matches prefix: {prefix}")
        exit(1)
    }
    let inner = strip_json_array(result)
    let sep = "{rbrace()},{lbrace()}"
    if inner.contains(sep) {
        io.eprintln("Ambiguous prefix '{prefix}', multiple matches")
        exit(1)
    }
    let clean = clean_json_row(inner)
    parse_json_field(clean, "id")
}

fn tags_for_task(task_id: Str) -> Str {
    let result = db_query("SELECT tag FROM tags WHERE task_id = '{task_id}'")
    if is_empty_json(result) {
        return ""
    }
    let mut tags: List[Str] = []
    let rows = split_json_rows(result)
    for row in rows {
        let clean = clean_json_row(row)
        let tag = parse_json_field(clean, "tag")
        if !tag.is_empty() {
            tags.push(tag)
        }
    }
    tags.join(", ")
}

fn parse_rows_as_task_lines(result: Str) {
    let rows = split_json_rows(result)
    for row in rows {
        let clean = clean_json_row(row)
        let id = parse_json_field(clean, "id")
        let title = parse_json_field(clean, "title")
        let priority_str = parse_json_field(clean, "priority")
        let status = parse_json_field(clean, "status")
        let tags = parse_json_field(clean, "tags")
        let mut priority = 2
        if !priority_str.is_empty() { priority = priority_str.to_int() }
        io.println(format_task_line(id, title, priority, status, tags))
    }
}

// --- CRUD Commands ---

pub fn cmd_add(title: Str, description: Str, priority: Int, tag_list: List[Str]) {
    let id = generate_id()
    let t = sql_escape(title)
    let d = sql_escape(description)
    db_exec("INSERT INTO tasks (id, title, description, priority) VALUES ('{id}', '{t}', '{d}', {priority})")

    for tag in tag_list {
        let tg = sql_escape(tag)
        db_exec("INSERT OR IGNORE INTO tags (task_id, tag) VALUES ('{id}', '{tg}')")
    }

    io.println("Created: {short_id(id)}  {title}")
}

pub fn cmd_ls(status_filter: Str, tag_filter: Str, json_mode: Bool) {
    let mut where_parts: List[Str] = []
    if !status_filter.is_empty() {
        let sf = sql_escape(status_filter)
        where_parts.push("t.status = '{sf}'")
    } else {
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

    let row = clean_json_row(strip_json_array(result))
    let title = parse_json_field(row, "title")
    let description = parse_json_field(row, "description")
    let status = parse_json_field(row, "status")
    let priority_str = parse_json_field(row, "priority")
    let mut priority = 2
    if !priority_str.is_empty() { priority = priority_str.to_int() }
    let created_at = parse_json_field(row, "created_at")
    let updated_at = parse_json_field(row, "updated_at")
    let closed_at = parse_json_field(row, "closed_at")
    let tags = tags_for_task(id)

    let blocks_result = db_query("SELECT blocked_id FROM deps WHERE blocker_id = '{id}'")
    let mut blocks_list: List[Str] = []
    if !is_empty_json(blocks_result) {
        let brows = split_json_rows(blocks_result)
        for br in brows {
            let bid = parse_json_field(clean_json_row(br), "blocked_id")
            blocks_list.push(short_id(bid))
        }
    }

    let blocked_by_result = db_query("SELECT blocker_id FROM deps WHERE blocked_id = '{id}'")
    let mut blocked_by_list: List[Str] = []
    if !is_empty_json(blocked_by_result) {
        let bbrows = split_json_rows(blocked_by_result)
        for bbr in bbrows {
            let bbid = parse_json_field(clean_json_row(bbr), "blocker_id")
            blocked_by_list.push(short_id(bbid))
        }
    }

    io.println(format_task_detail(id, title, description, status, priority, created_at, updated_at, closed_at, tags, blocks_list.join(", "), blocked_by_list.join(", ")))
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

pub fn cmd_start(id_prefix: Str) {
    cmd_edit(id_prefix, "", "", -1, "in_progress", false)
}

pub fn cmd_done(id_prefix: Str) {
    cmd_edit(id_prefix, "", "", -1, "done", false)
}

pub fn cmd_cancel(id_prefix: Str) {
    cmd_edit(id_prefix, "", "", -1, "cancelled", false)
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
                let dep_rows = split_json_rows(deps_result)
                for dr in dep_rows {
                    let did = parse_json_field(clean_json_row(dr), "blocked_id")
                    if !did.is_empty() {
                        stack.push(did)
                    }
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

pub fn cmd_blocked(json_mode: Bool) {
    let sql = "SELECT t.id, t.title, t.priority, t.status, COALESCE(GROUP_CONCAT(DISTINCT tg.tag), '') as tags, COALESCE(GROUP_CONCAT(DISTINCT d.blocker_id), '') as blockers FROM tasks t JOIN deps d ON d.blocked_id = t.id LEFT JOIN tags tg ON tg.task_id = t.id WHERE t.status NOT IN ('done', 'cancelled') GROUP BY t.id ORDER BY t.priority ASC"
    let result = db_query(sql)

    if json_mode {
        io.println(result)
        return
    }

    if is_empty_json(result) {
        io.println("No blocked tasks.")
        return
    }

    let rows = split_json_rows(result)
    for row in rows {
        let clean = clean_json_row(row)
        let id = parse_json_field(clean, "id")
        let title = parse_json_field(clean, "title")
        let priority_str = parse_json_field(clean, "priority")
        let status = parse_json_field(clean, "status")
        let tags = parse_json_field(clean, "tags")
        let blockers = parse_json_field(clean, "blockers")
        let mut priority = 2
        if !priority_str.is_empty() { priority = priority_str.to_int() }
        let line = format_task_line(id, title, priority, status, tags)
        io.println("{line}  (blocked by: {blockers})")
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
    let rows = split_json_rows(result)
    for row in rows {
        let clean = clean_json_row(row)
        let tag = parse_json_field(clean, "tag")
        let count = parse_json_field(clean, "count")
        io.println("  {tag}  ({count})")
    }
}

pub fn cmd_stats() {
    let result = db_query("SELECT status, COUNT(*) as count FROM tasks GROUP BY status ORDER BY status")
    if is_empty_json(result) {
        io.println("No tasks.")
        return
    }
    io.println("Tasks:")
    let rows = split_json_rows(result)
    for row in rows {
        let clean = clean_json_row(row)
        let status = parse_json_field(clean, "status")
        let count = parse_json_field(clean, "count")
        io.println("  {status}: {count}")
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
}
