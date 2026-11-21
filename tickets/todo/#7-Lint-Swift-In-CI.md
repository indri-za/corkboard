# #7 — Lint Swift in CI

**Type**: Chore
**Status**: Backlog

## Summary
Check Swift formatting in the same CI workflow as the tests, and fail the job when the tree does not match.

## Notes
- Use `swift-format`, which ships with the Swift toolchain. Do not add a Swift package dependency for this.
- Lint `Sources/` and `Tests/`. Leave `Package.swift` on tools version 5.10 and leave the Swift 5 language mode alone.
- Check only. CI should not rewrite files or open a pull request with formatting fixes.
- A local command should be able to apply the same format, so a failing check is easy to repair.
