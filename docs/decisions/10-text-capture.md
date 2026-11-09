---
date: 2026-11-05
issue: 10
status: superseded
superseded_by: 77-capture-only-from-outside-the-app.md
---

# Capture text by holding to dictate, with a keyboard as backup

**Decision:** The capture screen opens on a large mic button: hold it, speak, release, and the words become the capture. A small keyboard option sits alongside it.

**Why:** Speaking is the quickest way to get a rough idea down with a finger free. The keyboard is for places you can't speak aloud, and costs one text box. Hold-to-dictate has to live in the app because controls and widgets only take a single press. It needs Apple's Speech framework, as we know of no way for an app to start keyboard dictation itself. Rejected: `requestValue` from a control, which showed no text box on a locked phone in [the spike](../spikes/locked-capture.md), and wasn't tried unlocked once the app became the capture surface.
