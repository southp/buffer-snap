---
date: 2026-11-12
issue: 98
status: accepted
---

# The guide's steps are `LocalizedStringResource`s in Core

**Decision:** `DictationPlacement` holds each place's title and steps as `LocalizedStringResource`, and each step
names its sketch with a `Sketch` case. The app only draws them: `Text(step.text)`, and a SwiftUI drawing per sketch.

**Why:** Which places there are, their order and their steps are what the issue asks to unit test, and Core's tests
run in seconds without a simulator. `LocalizedStringResource` is Foundation, so Core stays UI-free, and it's what
localization (#100) looks up. They resolve against the main bundle, the app's, by default, while Xcode extracts a
package's strings into the package's own catalog: #100 has to either put these keys in the app's catalog or give them
Core's bundle. A view mapping cases to `Text` literals would have kept the strings in the
app but left the steps untested.
