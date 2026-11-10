---
date: 2026-11-10
issue: 84
status: accepted
---

# Bundle Inter and Caveat, unmodified, in the app and in the widget

**Decision:** `Shared/Fonts/` holds Inter and Caveat as Google Fonts publishes them, with their SIL Open Font License
files, and both targets copy them into their bundle and list them under `UIAppFonts` in their `Info.plist`. Views use
`Font.inter(_:weight:)` and `Font.caveat(_:)`, which are `Font.custom(_:size:relativeTo:)`, so they grow with Dynamic
Type.

| File | From `github.com/google/fonts` at `5bb28733cec313b63fbd415b574b5ae35c8aa8b8` | SHA-256 |
|---|---|---|
| `Inter.ttf` | `ofl/inter/Inter[opsz,wght].ttf` | `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031` |
| `Inter-OFL.txt` | `ofl/inter/OFL.txt` | `5b9321a4298cfeb6b34354164a1c3afc3db114569984c502b9b35d988fd58c57` |
| `Caveat.ttf` | `ofl/caveat/Caveat[wght].ttf` | `0bdb6b660482d31531b3945849fba5916b3ef8695da7024a9e6b9ee3c4157988` |
| `Caveat-OFL.txt` | `ofl/caveat/OFL.txt` | `1f9d81d094273d82f3898a1ee8b598a717d050ecbf5ff7bede105b704880157b` |

**Why:**

- **Both bundles:** the widget extension is a process of its own and only sees its own bundle's fonts. Without them,
  the widget and the Live Activity quietly fall back to the system font. `ThemeTests` checks that each bundle has them.
  The widget gets Caveat too, though it doesn't use it yet, because `Shared/` is copied as a whole: 400 KB.
- **Variable fonts, unmodified:** Google Fonts ships these two only as variable fonts. SwiftUI's `.weight(_:)` picks the
  weight from their `wght` axis, which the snapshots show for Inter's regular to heavy and for Caveat Bold, so there's
  no need to cut static instances, and the files stay byte for byte what the OFL licenses cover.
- **Caveat at 1.25 times Inter's size** for the same text style, because its letters are small for their size.

Rejected: the system font in the widget, which would have been the fallback if bundling it there didn't work.
