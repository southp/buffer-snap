---
date: 2026-11-17
issue: 109
status: accepted
---

# The guide's sketches move only when told to, so snapshots draw the still

**Decision:** `AddDictationGuideView` takes `animatesSketches`, and `DictationStepSketch` takes `isAnimated`. Only
`AddDictationGuideScreen` decides, as `!accessibilityReduceMotion`. When it's false, each sketch draws #98's still
`SketchTouch`, the same views as before, so the snapshots pass `animatesSketches: false` and their PNGs didn't change.
When it's true, the touch is a `SketchGestureTouch`: a repeating `KeyframeAnimator` that lands, taps, holds or swipes,
rests and lifts every 2.8 seconds. No snapshot renders the animated view.

**Why:** A snapshot of a running animation captures whatever frame it renders first, which depends on the run, so the
issue asks that no snapshot depend on animation timing. SwiftUI's `accessibilityReduceMotion` is read-only, so a test
can't turn it on through the environment, and a custom environment value would keep the switch out of the view's
signature, where the snapshot tests can't miss it. A flag the view takes follows the screen-and-stateless-view rule in
`App/CLAUDE.md`. Rejected: snapshotting the animator's first frame (it's `TouchPose.lifted`, an unseen touch, so it
would test nothing), and a `KeyframeTimeline` sampled at fixed times in tests (it pins timing values that are a design
choice, not behavior, and fails on every tweak).
