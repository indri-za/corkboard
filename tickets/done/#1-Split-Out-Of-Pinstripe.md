# #1 — Split out of pinstripe

**Type**: Chore
**Status**: Done

## Summary
Corkboard started as `tools/pinstripe-board` inside pinstripe-v2. It is now its own repository and does not import that project.

## Notes
- The column folders are the whole data model.
- A move must stay a git rename: same bytes, new directory.
