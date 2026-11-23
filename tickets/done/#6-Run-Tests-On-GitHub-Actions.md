# #6 — Run tests on GitHub Actions

**Type**: Chore
**Status**: Backlog

## Summary
Add a GitHub Actions workflow that builds this package and runs `swift test` on every push to `main` and every pull request.

## Notes
- Run on `macos-latest` (Apple silicon). The `macos-14` runner image was retired on 2 November 2026. `macos-15` is the other current label.
- The deployment target stays macOS 14. A newer runner can still build it.
- Commands run from the repository root. There is no `--package-path`.
- `swift test` is the suite in `Tests/CorkboardCoreTests`. It already covers parsing, sort, load, move, and create. CI should run that suite, not launch the window.
- Do not cache or commit `.build/`.
