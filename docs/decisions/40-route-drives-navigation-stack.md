---
date: 2026-11-05
issue: 40
status: accepted
---

# Push the capture list from the capture screen, driven by the route

**Decision:** `AppModel.route` has `.capture` and `.captureList`, and `RootView` shows both in one `NavigationStack`, pushing the list while the route is `.captureList`. Going back reports to `AppModel`, so the route stays the only owner of navigation.

**Why:** The capture screen stays alive under the list, so a draft survives a look at the list, and the system's back button and swipe work. It also gives #41 one call, `showCapture()`, for opening the capture screen whether or not the list is showing. Rejected: swapping screens in the route's `switch`, which destroys the draft unless the model moves up to the root, and has no back gesture. Also rejected: a `NavigationPath` with one possible value, which adds a second source of truth to keep in step for nothing.
