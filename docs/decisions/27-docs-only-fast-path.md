---
date: 2026-11-03
issue: 27
status: superseded
superseded_by: 102-docs-only-skips-ci.md
---

# Skip the simulator for PRs that only change an allowlist of safe files

**Decision:** The one `ci` job diffs a PR's merge commit against its first parent. If every changed file is on an
allowlist (`*.md`, `docs/*`, `LICENSE`, the two Claude workflows), it runs lint and Core tests only. Anything else,
an empty diff, a non-merge `HEAD` and every push to `main` take the full path.

**Why:** A docs-only PR waited about 10 minutes for a simulator its files can't affect. An allowlist fails safe: a new
kind of file gets the full run until someone adds it. Staying in one job means the required `ci` check always
reports a result. `--no-renames` lists a moved file under both names, so moving Swift
into `docs/` is not "safe". Rejected: the GitHub files API, which needs a wider token for what two commits of
history already answer.
