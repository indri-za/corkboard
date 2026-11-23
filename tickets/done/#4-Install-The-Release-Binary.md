# #4 — Install the release binary

**Type**: Task
**Status**: Todo

## Summary
Ad-hoc sign `.build/release/corkboard` and copy it onto `PATH` so any project can launch with `corkboard`.

## Notes
- macOS 14 or later. The binary links only the system Swift runtime.
- Finder and Spotlight do not inherit a project working directory. Use the terminal, or Open Project.
