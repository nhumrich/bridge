Cut a new Bridge release. The user's input after `/br:release` is the version number (e.g. `0.9.0`).

Steps:
1. Parse the version from the user's input. Strip a leading `v` if present.
2. Update the version string in `src/main.bl`: find `set_version(p, "...")` and replace the version.
3. Commit: `git add src/main.bl && git commit -m "Bump version to v<version>"`
4. Tag: `git tag v<version>`
5. Push: `git push && git push origin v<version>`

That's it — CI handles the rest (builds binaries, publishes GitHub Release, updates AUR).

Show the user the tag that was pushed and remind them to watch the Actions tab.
