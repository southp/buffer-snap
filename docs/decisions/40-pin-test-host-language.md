---
date: 2026-11-05
issue: 40
status: accepted
---

# Pin the test host's language in the scheme

**Decision:** The scheme's test action launches the test host with `-AppleLanguages (en-US)` and `-AppleLocale en_US`.

**Why:** Worktree simulators take the host Mac's language. Snapshots of the capture screen recorded on a zh-Hant simulator failed on an en-US one: its count and result labels sat 1px higher, while the text box and Save button didn't move. `assertScreenSnapshot` pins the SwiftUI locale, which didn't prevent this. Without the pin, a reference recorded on one machine could fail on another machine or on CI. Rejected: lowering the precision, which hides real changes of the same size, and adjusting this one screen's layout, which leaves every later screen open to the same failure.
