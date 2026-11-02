---
date: 2026-11-02
issue: 19
status: accepted
---

# Each issue writes to files it owns

**Decision:** Decisions live in `docs/decisions/<issue>-<slug>.md` (one per file, no index). Area notes live in that area's `CLAUDE.md`, each owned by one issue at a time; the root `CLAUDE.md` holds only stable repo-wide rules. Each worktree tests on its own simulator, `just lint` lints every Swift file git knows about, and each target's XcodeGen spec lives in its own folder.

**Why:** Parallel agents (one per issue, each in its own worktree) kept appending to the same lines: a single decision table, root `CLAUDE.md` sections, `justfile`'s `src_dirs` and `project.yml`. Those were guaranteed merge conflicts (#17 vs #18), and a shared simulator collides at runtime. Rejected: `.gitattributes merge=union` (GitHub doesn't apply merge drivers when computing PR mergeability) and sequential ADR numbers (two agents would take the same number).
