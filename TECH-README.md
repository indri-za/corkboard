# Corkboard

A macOS kanban board whose backend is a `tickets/` folder of markdown files.
Dragging a note moves the file between column folders. The app stores nothing
else, does not commit, and does not rewrite a ticket because it changed
column. Git, editors, and coding agents keep using the same files.

It is a general tool. The first board it was built against was the
pinstripe-v2 ticket workflow, and the column names come from that. The code
does not import or special-case that repository.

This directory is the whole project. It started life at
`tools/pinstripe-board` inside pinstripe-v2 and is meant to be its own git
repository. After the split, run every command below from this directory.

## What a board is

A board is a directory that contains at least one of these subdirectories:

```
tickets/
  backlog/       ideas, not ready
  todo/          ready to pick up
  in-progress/   active
  done/          shipped
```

You can point the app at the project root or at `tickets/` itself. Column
folders that are missing show as empty, and a drop into a missing column
creates that folder.

`placeholder.md` in a column is ignored. It exists so git keeps an otherwise
empty directory. Do not display it, and do not delete it.

Anything else ending in `.md` is a ticket. Hidden files and non-markdown
files are ignored. A file that cannot be read still appears, titled
"Couldn't read file", so it does not vanish from the board.

There is no order file. Within a column, notes sort by ticket number,
newest first. `104` comes before `23.31`, which comes before `23.10`, which
comes before `23.9`, which comes before `23`. Comparison is numeric per
dotted component, not alphabetical. A missing component sorts below one
that is present, so `23.10` comes before `23`. Notes with no number sink
to the bottom. Equal numbers then sort by filename in Finder order.
Dragging does not reorder within a column.

The directory is the status. A `**Status**:` line inside the file is often
stale (a done ticket may still say "Backlog"). Do not "fix" that on move.

The tape on a column uses `Column.title`: `Backlog`, `To Do`, `In Progress`,
`Done`. A ticket this app creates writes `Column.statusLabel` instead:
`Backlog`, `Todo`, `In progress`, `Done`. Those two spellings are
intentional. The menu and the tape say "To Do". The markdown says `Todo`.

## Ticket files

Real tickets are loose markdown, not a schema. The parser is deliberately
tolerant. Two shapes show up constantly:

```markdown
# #104 — Self-serve signup + Stripe (phase 2)

**Portal**: Marketing site + admin
**Type**: Feature (phase 2)
**Status**: Backlog

## Summary
One or two sentences.

## Notes
- Anything.
```

```markdown
# #23.22 Post-Event Export

**Status**: Complete

## Overview
Older tickets use Overview instead of Summary, and a space instead of an em dash.
```

Filenames look like `#104-Self-Serve-Signup-And-Stripe.md` or
`#23.22-Post-Event-Export.md`. The number may be dotted. The heading wins
over the filename when both exist.

On a card the app shows:

- The number, from the first `# ` heading, otherwise from the filename.
- The title, with a leading `#104 —` or `#23.22 ` stripped off.
- A rubber-stamp taken from `**Type**:`, cut at the first `/` or `(`,
  uppercased. `Bug (critical — live event)` stamps as `BUG`.
  `Infrastructure / DevOps / Reliability` stamps as `INFRASTRUCTURE`.
  A stamp longer than 18 characters is cut to 16.
- `**Portal**:`, with backticks removed.
- A short summary: the `## Summary` section, otherwise `## Overview`,
  otherwise the first paragraph after the title and the `**Key**:` lines.
  Inline markdown is stripped and the text is clipped at about 220 characters.
- The file's modification day.

`**Key**: value` lines are read only until the first `## ` heading. Keys are
matched case-insensitively. Unknown keys are kept in the file and ignored
by the card.

The detail view renders the raw file: headings, paragraphs, lists,
checkboxes (`- [ ]` and `- [x]`), fenced code, pipe tables, and quotes.
Bold, code, and links inside a paragraph or a table cell are interpreted.
A relative link is resolved against the ticket's own directory so
`../../docs/meetings/2026-08-20.md` opens as a file. Same-folder links such
as `./#47-Some-Ticket.md` point at a sibling, so they follow the file only
if someone updates them after a move. Links that go up at least one level
(`../done/…`, `../../docs/…`) stay valid, because every column is the same
depth.

## What the app will and will not change

Move: `FileManager.moveItem` into the destination column, same filename.
The bytes are unchanged, so git detects a rename. If that filename is
already in the destination, the move is refused.

Create, from the **+** on a column or from File → New Ticket (⌘N, which
defaults to To Do). The next number is one higher than the largest *first*
component already on the board. `#23.22` and `#104` produce `#105`, not
`#23.23` and not a filled gap. The filename is `#<number>-<Slug>.md`. The
slug is the title split on anything that is not a letter or digit, each word
capitalised, joined with hyphens, capped at 48 characters. A clash gets
`-2`, `-3`, and so on. The body is only:

```markdown
# #105 — Title the user typed

**Type**: Feature
**Status**: Todo

## Summary
The summary they typed.

## Notes
- 
```

`**Type**:` is omitted when the type field is blank. `**Status**:` uses
`Backlog`, `Todo`, `In progress`, or `Done` to match the column. The user's
title is kept as typed. The slug is only for the filename.

The app never deletes a ticket, never reorders by writing a position, never
runs git, and never edits a file it did not just create.

Search is case-insensitive and matches the number, title, type, portal,
status line, summary, filename, and full body. A filtered column badge
reads `visible/total`.

The board polls the four column directories about once a second. A change
in path, modification time, or size reloads. An agent moving or editing a
file shows up without a manual refresh. ⌘R reloads immediately. The open
detail follows the file by filename, so a move does not close it. If that
filename disappears, the detail closes.

## Launch

The process working directory is what matters. Run it from a terminal
sitting in the project (or any subdirectory):

```bash
corkboard
```

Discovery order:

1. The first argument that does not start with `-`. A relative path is
   resolved against the working directory. Accepted values are a project
   root, a `tickets/` directory, or a single column directory.
2. `CORKBOARD_TICKETS` or `CORKBOARD_ROOT`.
3. Walk upward from the working directory, at most 16 levels. The nearest
   match wins. A directory matches if it is a board, or if it contains a
   `tickets/` board.

There is no memory of the last project. The same binary is supposed to open
a different board every time you run it. Finder's Open panel (⌘O) does
remember the folder it last started in (`UserDefaults` key
`corkboard.panelDirectory`) and that is only the panel's starting
directory.

Favourites and recents live in a floating palette, shown and hidden with
⌘B (View → Show Projects). Opening a board records it. Pinning keeps it,
and the pins can be reordered by dragging. Neither list is read when the
app chooses a folder at launch. The list is `UserDefaults` key
`corkboard.projectLibrary`. The palette is a utility panel, not a second
document: closing the board closes it, and the app still quits when the
last board window closes.

Opening the binary from Finder or Spotlight does not use a project as the
working directory. The board then shows the empty cork and asks you to open
a folder. Use the terminal when you want the current directory.

If nothing matches, the window still opens. It shows the working directory
and an Open Project button.

The process is a normal foreground app: it appears in the Dock, activates
on launch, and quits when the last window closes.

## Install

macOS 14 or later. A release build links only the system Swift runtime
and AppKit, SwiftUI, Foundation, and Combine. It does not need Xcode after
it is copied. On Apple silicon the binary is arm64. Ad-hoc sign it so a
copied binary still launches.

From this directory:

```bash
swift build -c release
codesign --force --sign - .build/release/corkboard
cp .build/release/corkboard /usr/local/bin/
```

A tag named `v*`, for example `v0.1.0`, runs the same build on GitHub
Actions and attaches `corkboard-macos.zip` to the GitHub Release. The zip
contains the `corkboard` binary. That is the downloadable copy. A local
build still works.

If this folder is still nested inside another repository, add
`--package-path` pointing at it to `swift build`, `swift run`, and
`swift test`, and copy from that directory's `.build/release/corkboard`.

`.build/` is gitignored. Do not commit the binary.

Examples once it is on `PATH`:

```bash
cd ~/development/some-project
corkboard

corkboard ~/development/other-project
CORKBOARD_TICKETS=~/development/other-project/tickets corkboard
```

During development, `swift run` from this directory builds and launches the
debug binary. Its working directory is still the shell's. Pass a board
after `--`, because arguments before that belong to SwiftPM:

```bash
swift run -- ~/development/some-project
```

## Using the window

The window is a cork board in a wood frame, on purpose. Column names are
masking tape. Notes are pinned paper. Controls are glossy, in the spirit of
early iPhone OS. Fonts are Marker Felt (numbers and tape), Noteworthy
(titles), American Typewriter (body), and Helvetica Neue (the leather
header and the glossy buttons). Textures are drawn in code.
There are no image assets. Keep that material quality. A flat redesign is a
product change, not a cleanup.

- Click a note to read it. Editor opens the file in the default app.
  Finder reveals it. Move sends it to another column. The same actions are
  on the note's context menu, plus Copy Filename.
- Drag a note onto another column. The drag payload is the plain string
  `corkboard-ticket:<filename>`. The column drop looks that filename up and
  moves the file.
- **+** on a tape creates a ticket in that column. ⌘N creates one in To Do.
- The search field filters every column. Escape closes the new-ticket
  sheet, then the open note, then clears the search.
- ⌘O opens a project. ⌘B shows or hides the projects palette. ⌘R reloads.
  Show Tickets in Finder is in the File menu.
- Hover straightens a note and lifts it. Tilt and paper colour are a stable
  hash of the filename, so a reload does not reshuffle the board.

## Layout

```
Package.swift
.swift-format                   swift-format rules. Indent stays four spaces.
scripts/swift-format.sh         lint, or format to repair a failing check
.github/workflows/ci.yml        test and lint on push to main and on pull requests
.github/workflows/release.yml   a v* tag builds, signs, and publishes the zip
Sources/CorkboardCore/          Foundation only. This is the tested library.
  Column.swift                  the four columns and their status labels
  Ticket.swift                  the card model, search, and sort
  TicketParser.swift            markdown to a card
  TicketRoot.swift              finding a board from a path or a walk upward
  MarkdownDocument.swift        block parser used by the detail view
  BoardStore.swift              load, poll signature, move, create
  ProjectLibrary.swift          favourites, recents, and their UserDefaults store
Sources/Corkboard/              SwiftUI + AppKit. Not unit tested.
  CorkboardApp.swift            @main, boot, menu commands
  BoardView.swift               window, header, empty state, one-second poll
  ProjectsPalette.swift         the floating projects palette
  ProjectsPaletteController.swift  panel, ⌘B, frame memory
  ColumnView.swift              tape, notes, drag and drop
  StickyNoteView.swift
  DetailView.swift
  NewTicketSheet.swift
  MarkdownView.swift            renders MarkdownDocument, rewrites links
  Skeuo.swift                   colours, type, cork, wood, icon, open panel
Tests/CorkboardCoreTests/BoardTests.swift
```

`Package.swift` uses tools version 5.10 so a Swift 6 compiler stays in
Swift 5 language mode. The executable product is named `corkboard`.
The targets and modules are `Corkboard` and `CorkboardCore`.
Leave the language mode alone unless you are ready to deal with strict
concurrency across AppKit.

Core must stay free of SwiftUI and AppKit so `swift test` does not open a
window. UI code calls into `BoardStore`.

## Tests

```bash
swift test
scripts/swift-format.sh          # the CI lint check
scripts/swift-format.sh format  # write that format locally
```

GitHub Actions runs `swift test` and `scripts/swift-format.sh lint` on
every push to `main` and every pull request. The runner is `macos-latest`.
The check does not rewrite files and does not launch the window. `swift-format`
is the copy in the Xcode toolchain. The rules live in `.swift-format`.
`Package.swift` is left alone, including the Swift 5 language mode.

The suite covers the house title formats, numeric sort, load, move
(byte-for-byte), create, discovery from a nested directory, and the
markdown block parser. One test walks five directories up from the test
file and, if that location contains a `tickets/` board, parses it and
checks that every note has a title and that `placeholder.md` was skipped.
In this nested checkout that location is the pinstripe-v2 board. In a
standalone clone the walk misses and the test returns without failing.
Do not turn that into a hard dependency on another repo.

When you change parsing or file moves, extend `BoardTests` rather than
only launching the app.

## Checks that need the window

`swift test` does not draw anything. For a UI change, run the app against
a real `tickets/` folder and use it: open a note, search, start a new note,
and cancel without saving if you do not mean to add a file.

Screen recording may be unavailable in an agent session. The live window
is still scriptable through Accessibility (`AXUIElement` on the
`corkboard` process). Notes expose a description like
`#88, Production infrastructure…`. Pressing that element opens the detail.
The search field is the `AXTextField`. Column groups are labelled
`Backlog column` and so on. A `LazyVStack` only materialises visible notes,
so a long Done column will not list every file in the accessibility tree.

Do not point a destructive test at someone's real board. Move and create
write straight into the folders.

## Decisions to keep

- The folders are the product. No database, no sidecar index, no hidden
  metadata file.
- Moving a card must not change file bytes.
- Do not auto-commit, and do not shell out to git.
- Do not reopen the previous project when the working directory has no board.
  The projects palette is opened on purpose. It is not a launch source.
- `placeholder.md` stays invisible.
- Parsing must tolerate the variations above. A new ticket feature that only
  understands one template will hide real notes.
- The skeuomorphic board is the look. Glossier, more paper, more cork is in
  scope. Replacing it with a system sidebar and plain rows is not, unless
  someone asks.
- The tool stays project-agnostic. Do not hardcode a repo path, a ticket
  number, or one team's column names beyond the four folders.

## Splitting this into its own repo

Copy this directory and leave `.build/` behind. It is gitignored, and the
binary is rebuilt with the commands above. After the copy, this folder is
the repository root. Commands no longer need `--package-path`.

Nothing in the source imports pinstripe-v2. Do not add a path, a ticket
number, or a submodule that points back at it. The optional test that
walks up to a real `tickets/` folder already returns without failing when
that folder is gone.

The pinstripe-v2 workflow skill and that repo's README describe the ticket
folders for that project. They are not part of this tool. Leave them alone
when the tool moves.

## Picking this up in a later session

Read this file, then `BoardStore.swift`, `TicketParser.swift`, and
`TicketRoot.swift`. Run `swift test`. Launch with `swift run` from a
checkout that contains `tickets/`, or `swift run -- /path/to/that/checkout`.
Treat a UI change as unfinished until the running window has been
exercised, not only compiled.

The core library is Foundation and Combine only. Every file under
`Sources/Corkboard/` imports `CorkboardCore`. Forgetting that
import makes `Column`, `Ticket`, and `BoardStore` look undefined.

`slug` and `template` are static. Call `Self.slug` and `Self.template`.
An instance call does not compile in this language mode.

`GlossyBackground` is a `View`. Put it in a `background` and clip it.
It is not a `ShapeStyle`, so `Circle().fill(GlossyBackground(...))` does
not compile. `RoundGlossButton` is the pattern to copy.

Boot runs once. `CorkboardApp` keeps `@State didBoot` and calls
`bootstrap` from `onAppear`, using `FileManager.default.currentDirectoryPath`,
`CommandLine.arguments` after the program name, and the process environment.
An empty board is a successful boot. Do not return early because no column
has files, or the window never discovers the project.

Only File → New Ticket owns ⌘N. The green plus in the header creates a
ticket in To Do and its help text mentions ⌘N, but the button itself has
no shortcut. The plus on a tape creates in that column and has no shortcut
either. Adding `.keyboardShortcut("n")` to either button steals the menu
command.

Pinning a new ticket writes the file, shows the banner "Added #N" for
about 2.6 seconds, and closes the sheet. It does not open the detail.
Cancel closes the sheet and writes nothing. The sheet previews
`BoardStore.nextNumber()` before anything is saved.

A note is a plain `Button`, with the drag handler on that button. A press
through Accessibility opens the detail. An `onTapGesture` does not show up
as a press. The accessibility label is `"#88, Title"`. Column groups are
labelled `Backlog column`, `To Do column`, `In Progress column`, and
`Done column`.

The window has a hidden title bar, a full-size content view, and a
background that can drag the window. The default size is 1280×840 and the
minimum is 980×640. The scheme is light. The header's leading padding is
86 points so the title clears the traffic lights. `WindowChrome` in
`Skeuo.swift` applies the AppKit window flags.

The one-second refresh is `Task.sleep` inside `BoardView.watchDisk`,
started from `.task`. It is not a `Timer`. The signature is path,
modification time, and size for every file in the four column directories.
A move reloads, and the open detail follows the filename. If that filename
is gone, the detail closes.

The drag payload is the plain string `corkboard-ticket:<filename>`.
`NSString` registers that as `public.utf8-plain-text`, and both the column
and the note accept that type. Asking for `public.plain-text` highlights
the lane and then fails to decode, so the note snaps back. The load runs
off the main thread and calls `BoardStore.move` back on the main thread.
`move` uses
`FileManager.moveItem` and refuses a same-name collision. A missing
destination column is created.

Screen recording is often unavailable in an agent session, and
`CGWindowListCreateImage` is gone on recent macOS. Drive the live window
through Accessibility on the `corkboard` process. A `LazyVStack`
only materialises notes that are on screen, so a long Done column will not
list every file. Do not create or move a ticket on a real board unless
that was the request. `swift test` uses temporary directories for move and
create.

The release binary in a nested checkout, if one has been built, is
`.build/release/corkboard` under this directory, ad-hoc signed with
`codesign --force --sign -`. It is not source. A fresh clone builds its own.
