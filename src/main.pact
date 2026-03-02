import std.args
import db
import commands

fn args_positionals_from(a: Args, start: Int) -> List[Str] {
    let mut result: List[Str] = []
    let mut i = start
    while i < args_positional_count(a) {
        result.push(args_positional(a, i))
        i = i + 1
    }
    result
}

fn build_parser() -> ArgParser {
    let mut p = argparser_new("br", "Bridge Task Manager")

    p = add_flag(p, "--json", "-j", "JSON output")
    p = add_flag(p, "--version", "-V", "Print version")

    p = add_command(p, "add", "Add a new task")
    p = command_add_positional(p, "add", "title", "Task title")
    p = command_add_option(p, "add", "-p", "", "Priority (0=highest)")
    p = command_add_option(p, "add", "-t", "", "Tag (repeatable)")
    p = command_add_option(p, "add", "-d", "", "Description")
    p = command_add_option(p, "add", "--session", "", "Session ID")

    p = add_command(p, "ls", "List tasks")
    p = command_add_option(p, "ls", "-s", "", "Filter by status")
    p = command_add_option(p, "ls", "-t", "", "Filter by tag")
    p = command_add_flag(p, "ls", "--closed", "-c", "Show closed tasks")
    p = command_add_flag(p, "ls", "--all", "-a", "Show all tasks")

    p = add_command(p, "list", "List tasks")
    p = command_add_option(p, "list", "-s", "", "Filter by status")
    p = command_add_option(p, "list", "-t", "", "Filter by tag")
    p = command_add_flag(p, "list", "--closed", "-c", "Show closed tasks")
    p = command_add_flag(p, "list", "--all", "-a", "Show all tasks")

    p = add_command(p, "ready", "Show ready (unblocked) tasks")
    p = command_add_option(p, "ready", "-t", "", "Filter by tag")

    p = add_command(p, "show", "Show task details")
    p = command_add_positional(p, "show", "id", "Task ID prefix")

    p = add_command(p, "edit", "Edit a task")
    p = command_add_positional(p, "edit", "id", "Task ID prefix")
    p = command_add_option(p, "edit", "--title", "", "New title")
    p = command_add_option(p, "edit", "--desc", "", "New description")
    p = command_add_option(p, "edit", "-p", "", "New priority")
    p = command_add_option(p, "edit", "-s", "", "New status")
    p = command_add_flag(p, "edit", "--append", "", "Append to description")

    p = add_command(p, "start", "Start a task")
    p = command_add_positional(p, "start", "id", "Task ID prefix")
    p = command_add_option(p, "start", "--session", "", "Session ID")

    p = add_command(p, "done", "Complete a task")
    p = command_add_positional(p, "done", "id", "Task ID prefix")
    p = command_add_option(p, "done", "--session", "", "Session ID")

    p = add_command(p, "close", "Complete a task")
    p = command_add_positional(p, "close", "id", "Task ID prefix")
    p = command_add_option(p, "close", "--session", "", "Session ID")

    p = add_command(p, "stop", "Stop working on a task (back to open)")
    p = command_add_positional(p, "stop", "id", "Task ID prefix")
    p = command_add_option(p, "stop", "--session", "", "Session ID")

    p = add_command(p, "cancel", "Cancel a task")
    p = command_add_positional(p, "cancel", "id", "Task ID prefix")
    p = command_add_option(p, "cancel", "--session", "", "Session ID")

    p = add_command(p, "rm", "Delete a task")
    p = command_add_positional(p, "rm", "id", "Task ID prefix")

    p = add_command(p, "dep", "Manage dependencies")
    p = add_command(p, "dep.add", "Add dependency")
    p = command_add_positional(p, "dep.add", "blocker", "Blocker task ID")
    p = command_add_positional(p, "dep.add", "blocked", "Blocked task ID")
    p = add_command(p, "dep.rm", "Remove dependency")
    p = command_add_positional(p, "dep.rm", "blocker", "Blocker task ID")
    p = command_add_positional(p, "dep.rm", "blocked", "Blocked task ID")

    p = add_command(p, "blocked", "Show blocked tasks")
    p = command_add_option(p, "blocked", "-t", "", "Filter by tag")

    p = add_command(p, "tag", "Add tags to task")
    p = command_add_positional(p, "tag", "id", "Task ID prefix")

    p = add_command(p, "untag", "Remove tags from task")
    p = command_add_positional(p, "untag", "id", "Task ID prefix")

    p = add_command(p, "tags", "List all tags")
    p = add_command(p, "stats", "Show task statistics")
    p = command_add_option(p, "stats", "-t", "", "Filter by tag")
    p = add_command(p, "install", "Install Claude Code commands")
    p = add_command(p, "uninstall", "Remove Claude Code commands")
    p = add_command(p, "version", "Print version")

    p
}

fn main() {
    init_db()

    let p = build_parser()
    let a = argparse(p)
    let err = args_error(a)
    if err == "help" { exit(0) }
    if err != "" {
        io.eprintln(err)
        exit(1)
    }

    let cmd = args_command(a)
    let json_mode = args_has(a, "json")

    if args_has(a, "version") {
        io.println("br 0.1.0")
        exit(0)
    }

    if cmd == "" {
        io.println(generate_help(p))
        exit(0)
    }

    let session_id = args_get(a, "session")

    if cmd == "add" {
        let title = args_positional(a, 0)
        if title == "" {
            io.eprintln("Usage: br add <title> [-p N] [-t tag] [-d desc]")
            exit(1)
        }
        let priority_str = args_get(a, "p")
        let mut priority = 2
        if !priority_str.is_empty() { priority = priority_str.to_int() }
        let description = args_get(a, "d")
        let tags = args_get_all(a, "t")
        cmd_add(title, description, priority, tags, session_id)
    } else if cmd == "ls" || cmd == "list" {
        let status_filter = args_get(a, "s")
        let tag_filter = args_get(a, "t")
        let show_closed = args_has(a, "closed")
        let show_all = args_has(a, "all")
        cmd_ls(status_filter, tag_filter, json_mode, show_closed, show_all)
    } else if cmd == "ready" {
        let tag_filter = args_get(a, "t")
        cmd_ready(tag_filter, json_mode)
    } else if cmd == "show" {
        let id = args_positional(a, 0)
        if id == "" {
            io.eprintln("Usage: br show <id>")
            exit(1)
        }
        cmd_show(id, json_mode)
    } else if cmd == "edit" {
        let id = args_positional(a, 0)
        if id == "" {
            io.eprintln("Usage: br edit <id> [--title T] [--desc D] [-p N] [-s status]")
            exit(1)
        }
        let title = args_get(a, "title")
        let description = args_get(a, "desc")
        let priority_str = args_get(a, "p")
        let mut priority = -1
        if !priority_str.is_empty() { priority = priority_str.to_int() }
        let status = args_get(a, "s")
        let append = args_has(a, "append")
        cmd_edit(id, title, description, priority, status, append)
    } else if cmd == "start" {
        let id = args_positional(a, 0)
        if id == "" {
            io.eprintln("Usage: br start <id>")
            exit(1)
        }
        cmd_start(id, session_id)
    } else if cmd == "stop" {
        let id = args_positional(a, 0)
        if id == "" {
            io.eprintln("Usage: br stop <id>")
            exit(1)
        }
        cmd_stop(id, session_id)
    } else if cmd == "done" || cmd == "close" {
        let id = args_positional(a, 0)
        if id == "" {
            io.eprintln("Usage: br done <id>")
            exit(1)
        }
        cmd_done(id, session_id)
    } else if cmd == "cancel" {
        let id = args_positional(a, 0)
        if id == "" {
            io.eprintln("Usage: br cancel <id>")
            exit(1)
        }
        cmd_cancel(id, session_id)
    } else if cmd == "rm" {
        let id = args_positional(a, 0)
        if id == "" {
            io.eprintln("Usage: br rm <id>")
            exit(1)
        }
        cmd_rm(id)
    } else if cmd == "dep add" {
        let blocker = args_positional(a, 0)
        let blocked = args_positional(a, 1)
        if blocker == "" || blocked == "" {
            io.eprintln("Usage: br dep add <blocker> <blocked>")
            exit(1)
        }
        cmd_dep_add(blocker, blocked)
    } else if cmd == "dep rm" {
        let blocker = args_positional(a, 0)
        let blocked = args_positional(a, 1)
        if blocker == "" || blocked == "" {
            io.eprintln("Usage: br dep rm <blocker> <blocked>")
            exit(1)
        }
        cmd_dep_rm(blocker, blocked)
    } else if cmd == "dep" {
        io.println(generate_command_help(p, "dep"))
    } else if cmd == "blocked" {
        let tag_filter = args_get(a, "t")
        cmd_blocked(tag_filter, json_mode)
    } else if cmd == "tag" {
        let id = args_positional(a, 0)
        let tags = args_positionals_from(a, 1)
        if id == "" || tags.is_empty() {
            io.eprintln("Usage: br tag <id> <tag> [tag...]")
            exit(1)
        }
        cmd_tag(id, tags)
    } else if cmd == "untag" {
        let id = args_positional(a, 0)
        let tags = args_positionals_from(a, 1)
        if id == "" || tags.is_empty() {
            io.eprintln("Usage: br untag <id> <tag> [tag...]")
            exit(1)
        }
        cmd_untag(id, tags)
    } else if cmd == "tags" {
        cmd_tags()
    } else if cmd == "stats" {
        let tag_filter = args_get(a, "t")
        cmd_stats(tag_filter)
    } else if cmd == "install" {
        cmd_install()
    } else if cmd == "uninstall" {
        cmd_uninstall()
    } else if cmd == "version" {
        io.println("br 0.1.0")
    } else {
        io.eprintln("Unknown command: {cmd}")
        io.eprintln("Run 'br --help' for usage")
        exit(1)
    }
}
