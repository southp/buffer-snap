---
date: 2026-11-08
issue: 47
status: accepted
---

# Take App Store screenshots with one recipe, and show the Live Activity from snapshot renders

**Decision:** `just store-screenshots` builds the Debug app, runs it past sign-in with `-mockAuth signedIn` on an
iPhone 17 Pro Max and an iPhone 17 Pro simulator, seeds sample captures into the App Group file, taps through with
AXe, and saves the 6.9" and 6.3" sets into `build/store-screenshots/`. The Live Activity and the Dictate widget come
from the snapshot tests' PNGs, cut out of their background and put under a caption with headless Chrome. Nothing is
committed: the PNGs go on `pr-media` for review and straight to App Store Connect.

**Why:**

- **One command,** because the list changes in #46 after this, and the screenshots must follow without anyone
  redoing them by hand.
- **The two sizes App Store Connect takes for iPhone today:** the 6.3" one it requires and the 6.9" one it prefers,
  which also stands in for the 6.5" slot. Simulators of those models give the exact pixel sizes, so nothing is scaled.
- **Snapshot renders for the Live Activity and the widget:** the simulator has no microphone path to show a real
  dictation, and a widget's content needs SpringBoard driven by hand. The renders are the same SwiftUI views the
  iPhone draws, and they're already kept up to date by the tests.
- **Seeded captures, not mocked views:** the list is the real app, in the state a user sees after a few minutes.

Rejected:

- **fastlane snapshot:** a UI-test target and a Ruby toolchain for five screenshots.
- **A UI test that navigates:** it would run on every `just test` for screenshots taken once a release.
- **Committing the PNGs:** with rebase merges, binaries stay in `main`'s history forever (`33-pr-media-branch.md`).
