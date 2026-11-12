---
date: 2026-11-12
issue: 98
status: accepted
---

# Show how to add Dictate an Idea, since no app can add it

**Decision:** BufSnap can't put Dictate an Idea in Control Center, on the Lock Screen, on the Action button or on the
Home Screen itself, so it shows how: a How to Add guide, opened from the account menu and from the empty list's
Show Me How, with the steps for each place and a still Paper & Ink sketch beside each step. It's never shown by itself.
All four places always show, and the Action button's says "iPhone 15 Pro and later" instead of the app guessing
which iPhone it's on. The steps live in Core (`DictationPlacement`) and match the support page word for word.

**Why:** The iOS 27.2 SDK has no API that adds a control or a widget for an app: WidgetKit's `ControlCenter` can only
list the controls already added (`currentControls()`) and reload them, and `ControlWidget` only puts the control in
the system's gallery. A Discord user asked for a button that adds it, which iOS doesn't allow, or an animation of how
to. Sketches, not screenshots: a screenshot shows iOS's own UI in one language and one version, and goes out of date
with the next iOS. Animating them is #109. Not shown by itself: the empty list already points to it, and the app
already asks for two permissions at launch (#77). No device-model detection: the list of models with an Action button
would need updating with every new iPhone.
