---
date: 2026-10-31
issue: 5
status: accepted
---

# Shared pure-Swift Core package with observable view models

**Decision:** Architecture: shared pure-Swift **SPM Core** package; `@Observable` view models over `Sendable` service protocols with mocks

**Why:** Core stays UI-free and testable with `swift test`; mocks let every component connect end to end before it's real
