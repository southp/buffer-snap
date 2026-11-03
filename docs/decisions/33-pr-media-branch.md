---
date: 2026-11-03
issue: 33
status: accepted
---

# Host PR screenshots and screencasts on a separate `pr-media` branch

**Decision:** PR media is committed to a `pr-media` branch that has no history in common with `main`, one `pr-<N>/`
folder per PR, and linked from the PR body by commit-pinned raw URLs. The branch is never deleted.

**Why:** Rebase merges land every commit of a PR on `main`, so media on an issue branch would stay in `main`'s history
for good, even if a later commit removed it. Rejected: GitHub's drag-and-drop uploads, which have no API, so agents
can't use them from a terminal; release assets, which would clutter the releases of an app that will ship real ones;
Git LFS, which is more setup for a few small files. The cost is that raw URLs can't play video, so screencasts are
shown as GIFs with the MP4 linked.
