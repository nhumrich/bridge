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

pub fn db_exec(sql: Str) {
    let db = db_path()
    let tmp = "/tmp/bridge_sql_{time_ms()}.sql"
    write_file(tmp, sql)
    let result = process_run("sh", ["-c", "sqlite3 '{db}' < '{tmp}'"])
    process_run("rm", ["-f", tmp])
    if result.exit_code != 0 {
        io.eprintln("db error: {result.err_out}")
        exit(1)
    }
}

pub fn db_query(sql: Str) -> Str {
    let db = db_path()
    let tmp = "/tmp/bridge_sql_{time_ms()}.sql"
    write_file(tmp, sql)
    let result = process_run("sh", ["-c", "sqlite3 -json '{db}' < '{tmp}'"])
    process_run("rm", ["-f", tmp])
    if result.exit_code != 0 {
        io.eprintln("db error: {result.err_out}")
        exit(1)
    }
    result.out.trim().replace("\n", "")
}

pub fn init_db() {
    let schema = "PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    status TEXT DEFAULT 'open' CHECK(status IN ('open','in_progress','done','cancelled')),
    priority INTEGER DEFAULT 2 CHECK(priority BETWEEN 0 AND 4),
    created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    closed_at TEXT
);
CREATE TABLE IF NOT EXISTS tags (
    task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    tag TEXT NOT NULL,
    PRIMARY KEY (task_id, tag)
);
CREATE TABLE IF NOT EXISTS deps (
    blocker_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    blocked_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    PRIMARY KEY (blocker_id, blocked_id)
);
CREATE INDEX IF NOT EXISTS idx_tags_tag ON tags(tag);
CREATE INDEX IF NOT EXISTS idx_deps_blocked ON deps(blocked_id);
CREATE INDEX IF NOT EXISTS idx_deps_blocker ON deps(blocker_id);"
    db_exec(schema)
}
