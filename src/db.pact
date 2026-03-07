pub fn db_path() -> Str {
    let home = get_env("HOME") ?? "/tmp"
    let dir = "{home}/.local/share/bridge"
    if is_dir(dir) == 0 {
        let result = process_run("mkdir", ["-p", dir])
        if result.exit_code != 0 {
            io.eprintln("Failed to create data directory: {result.err_out}")
            exit(1)
        }
    }
    "{dir}/bridge.db"
}

pub fn db_open_connection() {
    db.open(db_path())
}

pub fn init_db() {
    db_open_connection()
    db.exec("PRAGMA journal_mode=WAL")
    db.exec("PRAGMA foreign_keys=ON")
    db.exec("CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    status TEXT DEFAULT 'open' CHECK(status IN ('open','in_progress','done','cancelled')),
    priority INTEGER DEFAULT 2 CHECK(priority BETWEEN 0 AND 4),
    created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    closed_at TEXT
)")
    db.exec("CREATE TABLE IF NOT EXISTS tags (
    task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    tag TEXT NOT NULL,
    PRIMARY KEY (task_id, tag)
)")
    db.exec("CREATE TABLE IF NOT EXISTS deps (
    blocker_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    blocked_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    PRIMARY KEY (blocker_id, blocked_id)
)")
    db.exec("CREATE TABLE IF NOT EXISTS activity_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    session_id TEXT,
    project_path TEXT,
    created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
)")
    db.exec("CREATE INDEX IF NOT EXISTS idx_tags_tag ON tags(tag)")
    db.exec("CREATE INDEX IF NOT EXISTS idx_deps_blocked ON deps(blocked_id)")
    db.exec("CREATE INDEX IF NOT EXISTS idx_deps_blocker ON deps(blocker_id)")
    db.exec("CREATE INDEX IF NOT EXISTS idx_activity_task ON activity_log(task_id)")
}
