---
date: 2026-10-31
issue: 1
status: accepted
---

# Generate the Xcode project with XcodeGen

**Decision:** Generate the Xcode project with **XcodeGen** (`project.yml`); `*.xcodeproj` is gitignored

**Why:** Reviewable YAML instead of `pbxproj` merge conflicts; fits a terminal-only workflow
