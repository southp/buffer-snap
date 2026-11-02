---
date: 2026-11-02
issue: 12
status: accepted
---

# Review PRs with a custom prompt

**Decision:** Review PRs with a **custom prompt** in `claude-code-review.yml` instead of the generated `/code-review` plugin command

**Why:** The prompt has to point Claude at `CLAUDE.md` and at the acceptance criteria of the issue the PR closes, and a plain prompt makes that explicit
