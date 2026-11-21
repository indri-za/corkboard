# #8 — Publish release builds

**Type**: Chore
**Status**: Backlog

## Summary
Add a GitHub Actions workflow that, on a version tag, builds the release binary, ad-hoc signs it, and attaches it to a GitHub Release.

## Notes
- Trigger on tags named `v*`, for example `v0.1.0`. Use the same `macos-latest` Apple silicon runner as CI.
- Build with `swift build -c release`. The product name is `corkboard`.
- Ad-hoc sign with `codesign --force --sign -`, the same step as a local install. The binary links only the system Swift runtime.
- Zip that binary and upload it to the Release for the tag. Do not commit the binary or `.build/`.
- This does not replace installing from a local build. It is the copy someone downloads.
