---
date: 2026-11-12
issue: 97
status: accepted
---

# Caveat draws past its frame through a text renderer

**Decision:** Caveat is set only by the `.caveat(_:)` view modifier (`Shared/Theme.swift`). It applies the font
and a `TextRenderer` that draws the text unchanged but declares a `displayPadding` of 1/3 em on the leading and
trailing sides, scaled with Dynamic Type. `Font.caveat` is `fileprivate`, so `.font(.caveat(…))` can't skip it.

**Why:** Caveat's glyphs reach past their advance width (the bold "s" by 0.09 em, the widest glyph by 0.33 em), and
SwiftUI clips a `Text`'s drawing at its frame, inside a `List` or not. The last "s" of "Captures" was cut off. A
scratch snapshot showed that padding outside the `Text` or a wider frame doesn't help, because neither widens the
text's own drawing bounds. `displayPadding` widens only the drawing bounds, so the layout and every row stay where
they were. Trailing padding inside the frame would also work, but it moves the text's frame and needs a
spacer-like trick inside the `Text`, such as a trailing space or tracking, that changes how it lays out and reads to
VoiceOver. The bold is the font's own wght 700 instance, not a synthesized one: the rendered width matches the Bold
instance's advances.
