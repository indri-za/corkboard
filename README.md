# 📌 Corkboard

A macOS kanban board in your project folder.

Your tickets are just markdown files in a `tickets/` directory. Drag a ticket between columns and the file moves with it. You,  agents, Git and your editor can work from a common place. 

## Columns

| Folder | Column |
|---|---|
| `tickets/backlog/` | Backlog |
| `tickets/todo/` | To Do |
| `tickets/in-progress/` | In Progress |
| `tickets/done/` | Done |

Any `.md` file in a column folder is a ticket. Missing folders show as empty and are created when you drop into them.

## Install

Download the latest binary from [Releases](../../releases), or build from source:

```sh
swift build -c release
cp -L .build/release/corkboard /usr/local/bin/
```

## Usage

**Open from a project directory:**

```sh
cd my-project
corkboard
```

Corkboard walks up from the current directory looking for a `tickets/` folder. You can also point it at one directly:

```sh
corkboard path/to/tickets
```

Or set an environment variable:

```sh
export CORKBOARD_TICKETS=~/projects/my-app/tickets
corkboard
```

Print the version:

```sh
corkboard --version
```

Once open, use **File → Open Project…** (⌘O) to switch boards. **⌘B** shows a floating palette of pinned projects and boards you have opened. Pick one to load it. Corkboard still starts in the folder you launched it from, and does not reopen the last project on its own.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘N | New ticket |
| ⌘O | Open a different project |
| ⌘B | Show or hide the projects palette |
| ⌘R | Reload board |
| Esc | Close detail / dismiss dialog |

## How tickets work

A ticket is any `.md` file. Write whatever you like — Corkboard parses what it recognises and shows the rest as-is. A typical ticket looks like:

```markdown
# #12 — Fix the login bug

**Type**: Bug
**Status**: In progress

## Summary
Users can't log in after resetting their password.

## Notes
- Check the token expiry logic
```

The ticket number, title, type, and summary are pulled from the file and shown on the sticky note. Everything else appears when you click to expand.

## Contributing

See [TECH-README.md](TECH-README.md) for architecture, build details, and development notes.

## License

[MIT](LICENSE)
