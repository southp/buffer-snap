---
date: 2026-11-04
issue: 9
status: accepted
---

# Deploy every merge from the `ci` workflow, one run at a time

**Decision:** A `deploy` job in `ci.yml` runs `just deploy` after `ci` passes on a push to `main`. Runs on `main` no
longer cancel each other, while PR runs still do. The job runs `just _bootstrap-tools` rather than `just bootstrap`.

**Why:** Reusing the recipe keeps one deploy path, and CI only supplies the variables. Cancelling on `main` would have
dropped a merge followed quickly by another: #32, #34 and #36 merged within 24 s and cancelled each other's runs. Keeping
one group, rather than one per commit, also keeps deploys in merge order, so the newest build number always holds the
newest code. The cost is that GitHub keeps only one waiting run per group: with three quick merges the middle one is
skipped, and its commit ships inside the newest. That's fine for TestFlight, where only the latest build matters.
`just bootstrap` creates a simulator, which an archive doesn't need and which the image can't provide without a large
runtime download.
