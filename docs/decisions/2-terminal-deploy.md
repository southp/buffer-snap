---
date: 2026-11-03
issue: 2
status: accepted
---

# Deploy with plain `xcodebuild` and an App Store Connect API key

**Decision:** `just deploy` runs `xcodebuild archive` and `-exportArchive` with automatic signing, authenticated by an
Admin API key. Secrets come from the environment, with a gitignored `.env` for local use. The build number is a UTC
timestamp set at archive time, and `manageAppVersionAndBuildNumber` is off so Xcode can't replace it.

**Why:** It's one recipe with no new dependency, and CI can reuse it by providing the same variables (#9). Apple manages
the certificates and profiles, so there's nothing to rotate or leak in the repo. A timestamp increases on any machine
without a counter to store. Rejected: fastlane, which adds a Ruby toolchain for what two commands already do, and
committing signing assets. The team is left empty in simulator builds on a fresh clone: XcodeGen then keeps the literal
`${DEVELOPMENT_TEAM}`, which we tested building, testing and using the App Group fine, so only `deploy` requires it.
