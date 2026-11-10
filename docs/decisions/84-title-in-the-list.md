---
date: 2026-11-10
issue: 84
status: accepted
---

# Draw a screen's title as the first row of its list

**Decision:** A screen's handwritten title ("Captures", "Batching") is a `ScreenTitle` row at the top of its list, in
Caveat. The navigation bar keeps the title for the back button and VoiceOver, but doesn't show it
(`.toolbar(removing: .title)`), and stays inline.

**Why:** The navigation bar's large title can only take a custom font through `UINavigationBar`'s appearance, which
sets a fixed size when the bar is made, so it wouldn't grow with Dynamic Type, which the issue requires. A row in the
list is plain SwiftUI text, so it does, as the `largeText` snapshot shows. The cost is that the title scrolls away with
the list instead of shrinking into the bar.
