# Bridge

A local-only task list that persists across repos and AI sessions. 

Bridge is a dependency-aware task manager that persists globally across repos and sessions. It gives AI coding agents (and you) a shared view of what needs to be done, what's blocked, and what's ready to work on. It is designed only for local, and as such, has no concept of git or remote syncing. 


## Why

Dev workflows often live across multiple AI coding sessions. It can be helpful to have a place to manage them. Keeping track of a project in a single file means all sub-agents have to read the whole file. Sometimes and agent doesn't need the whole picture, but a peice. This is a task manager similar to beads that allows you to manage tasks for usage across sessions. This means sessions can either:
a) assign work to eachother
b) store "future work" of stuff to be done without effecting current session
c) pick up "work to be done" without you have to copy/paste or reference a file. 


## Features

- **Global task list**: tasks aren't scoped to a repo, they follow you everywhere
- **Dependencies**: tasks can have dependencies, so you can mark things to NOT be worked on until other work is completed
- **Priority + tags** — organize however you want with tags. Set priorities. 
- **Agent integration** — optional Claude Code plugin with slash commands (`/br:next`, `/br:plan`, `/br:add`)
- **Fast CLI** — single binary, no runtime dependencies, prefix-matching IDs

## Install

Download the latest binary from [Releases](https://github.com/nhumrich/bridge/releases):

```sh
# Linux (amd64)
curl -L https://github.com/nhumrich/bridge/releases/latest/download/br-linux-amd64 -o ~/.local/bin/br
chmod +x ~/.local/bin/br
```

I also recommend you add something to your CLAUDE/AGENTS.md so it knows to use `br`, such as:

```markdown
## Task Management
We track work in Bridge (`br`) — a global task manager. Run `br --help` to see commands.

### br Workflow
  1. Check what's ready: `br ready`
  2. Add tasks: `br add "task description" -p 0` (0=highest priority)
  3. Add dependencies: `br dep add <blocker> <blocked>` (first arg blocks second)
  4. Start work: `br start <id>`
  5. Complete work: `br close <id>`

  ### br Best Practices
  - Break down complex tasks into multiple issues with dependencies
  - Use `br ready` to see unblocked work before starting
  - Tags use `namespace:value` convention (e.g., `repo:bridge`, `feature`, `bug`)
  - Use `-t tag` to filter by tag
  - Use `br show <id>` for task details
```

### Agent integration (optional)

```sh
br install    # installs Claude Code slash commands
br uninstall  # removes them
```

## Usage

```
br add "my task" -p 0           # add task (priority 0 = highest)
br add "fix bug" -t repo:bridge # add with tag
br ready                        # show unblocked tasks
br start <id>                   # start working
br close <id>                   # complete task
br dep add <blocker> <blocked>  # add dependency
br blocked                      # show what's stuck
br ls                           # list open tasks
br stats                        # overview
```

Run `br --help` for all commands.

# Tags
Bridge supports tags. Tags are a very loosely opinionated system that lets you break down work however you want. You can tag things simply such as `[feature] [projecta]` or, you can use `:` notation for categories such as `repo:backend`, `repo:frontend`, `type:epic`, `project:foobar`, whatever you want. Just update your AI commands and workflows to tell it how you want to organize, and it does a good job. 
Also, putting `[]` around labels seems to work pretty well. For example:
`create a task on br [feature repo:other]` 

AI will figure out `[featue repo:other]` means add those two tags. 

# Tricks
I like to run `/br:plan` after a plan mode _instead of hitting accept plan_. It breaks the plan down into smaller steps. I then use `/clear` and `/br:next` and then the agent will pick up the work, and run the different tasks in parallel, each one only having the context of what it needs. 

I also sometimes like to keep adding tasks this way in a loop, while a different session picks up tasks from the "backlog" in a loop. 

## Build from source

Requires [Pact](https://github.com/nhumrich/pact).
```sh
pact build src/main.pact
cp build/main ~/.local/bin/br
```

## License

MIT

## Etymology

The bridge of a spaceship. It also bridges context between sessions.
