---
date: 2026-11-02
issue: 12
status: accepted
---

# Gate @claude runs on repo collaborators

**Decision:** Gate `@claude` runs twice: a workflow `if` on `author_association` (owner/member/collaborator), then the action's default write-access check; never set `allowed_non_write_users`

**Why:** Public repo, and runs bill the subscription: strangers' mentions are skipped before a runner starts, and read-only collaborators are still rejected
