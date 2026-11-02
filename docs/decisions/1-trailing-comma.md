---
date: 2026-11-02
issue: 1
status: accepted
---

# Require trailing commas in SwiftLint

**Decision:** Configure SwiftLint `trailing_comma` with `mandatory_comma: true`

**Why:** swift-format adds trailing commas to multi-line collections, which the default rule rejects; requiring them makes the two tools agree instead of disabling a rule
