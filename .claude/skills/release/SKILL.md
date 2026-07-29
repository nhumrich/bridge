---
description: Cut a new Bridge release
allowed-tools: Bash(git *), Bash(task *), Edit
---

Cut a new Bridge release. The user's input after `/release` is the version number (e.g. `0.9.0`).

Steps:
1. Parse the version from the user's input. Strip a leading `v` if present.
2. Bump the version everywhere: `task bump -- <version>`. This updates `blink.toml`, `src/main.bl` and `.claude-plugin/plugin.json` together — do not hand-edit any of them, or they will drift apart.
3. Commit: `git add blink.toml src/main.bl .claude-plugin/plugin.json && git commit -m "Bump version to v<version>"`
4. Tag: `git tag v<version>`
5. Push: `git push && git push origin v<version>`

CI handles the rest — builds binaries, publishes GitHub Release, updates AUR.

Show the user the tag that was pushed and remind them to watch the Actions tab.
