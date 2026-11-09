---
date: 2026-11-09
issue: 77
status: superseded
superseded_by: 81-only-the-dictate-widget.md
---

# The Lock Screen widget starts dictating with a button

**Decision:** The `SnapperWidget`'s two faces both run `DictateIdeaIntent`, through `Button(intent:)`: the Home Screen's Dictate button and the whole round face on the Lock Screen. The widget's kind doesn't change, so a placed widget stays and starts dictating.

**Why:** There's no capture screen left to open, and a press should dictate wherever it's made. A `widgetURL`, which `41-lock-screen-widget-url.md` chose, can only open the app, so it can't start listening with the app closed. Rejected: a `buffersnap://dictate` link that opens the app and starts from there, which puts the app on screen and drops the point of the widget.

**Not verified:** #41 found on an iPhone that this family's `Button(intent:)` opened the app without running an `openAppWhenRun` intent. `DictateIdeaIntent` is a different kind of intent, a `LiveActivityIntent` that runs in the background, and Apple lists `accessoryCircular` among the families that can hold buttons, but only an iPhone can show whether it runs. If it doesn't, the tap opens the app on the list. That's a harmless failure, and the Lock Screen's "Dictate an Idea" control is the way to dictate from there. Check this with `just device` before submitting.
