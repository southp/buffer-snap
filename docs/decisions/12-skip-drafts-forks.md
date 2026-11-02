---
date: 2026-11-02
issue: 12
status: accepted
---

# Skip drafts and forks in auto-review, cancel superseded runs

**Decision:** Auto-review skips draft PRs and fork PRs, and a new push cancels an in-flight review

**Why:** Drafts get reviewed on `ready_for_review`; forks can't read the OAuth secret; this avoids paying for reviews of superseded commits
