import db
import commands

fn usage() {
    io.println("br - Bridge Task Manager")
    io.println("")
    io.println("Usage: br <command> [options]")
    io.println("")
    io.println("Commands:")
    io.println("  add <title> [-p N] [-t tag] [-d desc]   Add a new task")
    io.println("  ls [-s status] [-t tag] [-j]            List tasks")
    io.println("  ready [-t tag] [-j]                     Show ready (unblocked) tasks")
    io.println("  show <id> [-j]                          Show task details")
    io.println("  edit <id> [--title T] [--desc D] [-p N] Edit a task")
    io.println("  start <id>                              Start a task")
    io.println("  done <id>                               Complete a task")
    io.println("  cancel <id>                             Cancel a task")
    io.println("  rm <id>                                 Delete a task")
    io.println("  dep add <blocker> <blocked>             Add dependency")
    io.println("  dep rm <blocker> <blocked>              Remove dependency")
    io.println("  blocked [-j]                            Show blocked tasks")
    io.println("  tag <id> <tag> [tag...]                 Add tags")
    io.println("  untag <id> <tag> [tag...]               Remove tags")
    io.println("  tags                                    List all tags")
    io.println("  stats                                   Show task statistics")
    io.println("  install                                 Install Claude Code commands")
    io.println("  uninstall                               Remove Claude Code commands")
}

fn get_flag(args: List[Str], flag: Str, alt: Str) -> Bool {
    let mut i = 0
    while i < args.len() {
        let a = args.get(i)
        if a == flag || a == alt {
            return true
        }
        i = i + 1
    }
    false
}

fn get_option(args: List[Str], flag: Str, alt: Str) -> Str {
    let mut i = 0
    while i < args.len() - 1 {
        let a = args.get(i)
        if a == flag || a == alt {
            return args.get(i + 1)
        }
        i = i + 1
    }
    ""
}

fn collect_rest(args: List[Str], start: Int) -> List[Str] {
    let mut result: List[Str] = []
    let mut i = start
    while i < args.len() {
        result.push(args.get(i))
        i = i + 1
    }
    result
}

fn collect_non_flag_args(args: List[Str], start: Int) -> List[Str] {
    let mut result: List[Str] = []
    let mut i = start
    while i < args.len() {
        let a = args.get(i)
        if !a.starts_with("-") {
            result.push(a)
        }
        i = i + 1
    }
    result
}

fn main() {
    init_db()

    let args = env.args()
    if args.len() < 2 {
        usage()
        exit(0)
    }

    let cmd = args.get(1)
    let rest = collect_rest(args, 2)
    let json_mode = get_flag(rest, "--json", "-j")

    if cmd == "add" {
        if rest.len() == 0 {
            io.eprintln("Usage: br add <title> [-p N] [-t tag] [-d desc]")
            exit(1)
        }
        let title = rest.get(0)
        let priority_str = get_option(rest, "-p", "-p")
        let mut priority = 2
        if !priority_str.is_empty() { priority = priority_str.to_int() }
        let description = get_option(rest, "-d", "-d")

        let mut tags: List[Str] = []
        let mut i = 0
        while i < rest.len() {
            if rest.get(i) == "-t" && i + 1 < rest.len() {
                tags.push(rest.get(i + 1))
            }
            i = i + 1
        }

        cmd_add(title, description, priority, tags)
    } else if cmd == "ls" || cmd == "list" {
        let status_filter = get_option(rest, "-s", "-s")
        let tag_filter = get_option(rest, "-t", "-t")
        cmd_ls(status_filter, tag_filter, json_mode)
    } else if cmd == "ready" {
        let tag_filter = get_option(rest, "-t", "-t")
        cmd_ready(tag_filter, json_mode)
    } else if cmd == "show" {
        if rest.len() == 0 {
            io.eprintln("Usage: br show <id>")
            exit(1)
        }
        cmd_show(rest.get(0), json_mode)
    } else if cmd == "edit" {
        if rest.len() == 0 {
            io.eprintln("Usage: br edit <id> [--title T] [--desc D] [-p N] [-s status]")
            exit(1)
        }
        let id = rest.get(0)
        let title = get_option(rest, "--title", "--title")
        let description = get_option(rest, "--desc", "--desc")
        let priority_str = get_option(rest, "-p", "-p")
        let mut priority = -1
        if !priority_str.is_empty() { priority = priority_str.to_int() }
        let status = get_option(rest, "-s", "-s")
        cmd_edit(id, title, description, priority, status)
    } else if cmd == "start" {
        if rest.len() == 0 {
            io.eprintln("Usage: br start <id>")
            exit(1)
        }
        cmd_start(rest.get(0))
    } else if cmd == "done" {
        if rest.len() == 0 {
            io.eprintln("Usage: br done <id>")
            exit(1)
        }
        cmd_done(rest.get(0))
    } else if cmd == "cancel" {
        if rest.len() == 0 {
            io.eprintln("Usage: br cancel <id>")
            exit(1)
        }
        cmd_cancel(rest.get(0))
    } else if cmd == "rm" {
        if rest.len() == 0 {
            io.eprintln("Usage: br rm <id>")
            exit(1)
        }
        cmd_rm(rest.get(0))
    } else if cmd == "dep" {
        if rest.len() == 0 {
            io.eprintln("Usage: br dep <add|rm> <blocker> <blocked>")
            exit(1)
        }
        let subcmd = rest.get(0)
        if subcmd == "add" {
            if rest.len() < 3 {
                io.eprintln("Usage: br dep add <blocker> <blocked>")
                exit(1)
            }
            cmd_dep_add(rest.get(1), rest.get(2))
        } else if subcmd == "rm" {
            if rest.len() < 3 {
                io.eprintln("Usage: br dep rm <blocker> <blocked>")
                exit(1)
            }
            cmd_dep_rm(rest.get(1), rest.get(2))
        } else {
            io.eprintln("Unknown dep subcommand: {subcmd}")
            exit(1)
        }
    } else if cmd == "blocked" {
        cmd_blocked(json_mode)
    } else if cmd == "tag" {
        if rest.len() < 2 {
            io.eprintln("Usage: br tag <id> <tag> [tag...]")
            exit(1)
        }
        let id = rest.get(0)
        let tags = collect_non_flag_args(rest, 1)
        cmd_tag(id, tags)
    } else if cmd == "untag" {
        if rest.len() < 2 {
            io.eprintln("Usage: br untag <id> <tag> [tag...]")
            exit(1)
        }
        let id = rest.get(0)
        let tags = collect_non_flag_args(rest, 1)
        cmd_untag(id, tags)
    } else if cmd == "tags" {
        cmd_tags()
    } else if cmd == "stats" {
        cmd_stats()
    } else if cmd == "install" {
        cmd_install()
    } else if cmd == "uninstall" {
        cmd_uninstall()
    } else if cmd == "help" || cmd == "--help" || cmd == "-h" {
        usage()
    } else {
        io.eprintln("Unknown command: {cmd}")
        io.eprintln("Run 'br help' for usage")
        exit(1)
    }
}
