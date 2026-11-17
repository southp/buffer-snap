---
date: 2026-11-17
issue: 109
status: accepted
---

# Each sketch's gesture is in Core

**Decision:** `DictationPlacementStep.Sketch.gesture` says what the finger does in each step: `tap`, `touchAndHold`,
`swipeDown` or `swipeLeft`. The app maps the gesture to motion (`SketchGestureTouch`) and to the still (a held touch
has a ring); each sketch only says where the touch is.

**Why:** "Each step animates its gesture" is the issue's acceptance criterion, and Core's tests check it in seconds,
next to the steps and sketches it belongs with (`docs/decisions/98-steps-are-localized-resources-in-core.md`). The
alternative, a per-sketch choice of animation inside the view, could only be checked by watching it.
