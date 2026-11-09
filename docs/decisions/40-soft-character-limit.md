---
date: 2026-11-05
issue: 40
status: superseded
superseded_by: 77-capture-only-from-outside-the-app.md
---

# Block saving over 300 characters instead of cutting off the text

**Decision:** A draft over 300 characters stays in the text box with its count in red, and Save is disabled until it's short enough. A character is what a person sees as one (a Swift `Character`), and surrounding whitespace doesn't count.

**Why:** Cutting the text off loses words without saying so, whether they were pasted or, once #42 lands, dictated. Rewriting the text from its binding as it's typed also fights the keyboard: it can break Chinese and Japanese composition, and SwiftUI may not redraw a field whose bound value didn't change, so the field can show more than the model holds.
