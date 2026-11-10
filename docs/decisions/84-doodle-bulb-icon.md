---
date: 2026-11-10
issue: 84
status: accepted
---

# Doodle Bulb is the app icon, with hand-made dark and tinted appearances

**Decision:** The icon is Doodle Bulb, exactly as the owner picked it: a yellow bulb in a thick ink outline with a red
sound-wave filament, on paper. `docs/design/app-icon.svg` holds the drawing once. A style block in the same file
recolors it for iOS 18's dark appearance (the same bulb on ink, with cream outlines) and its tinted one (white outlines
and a grey bulb on black, which iOS tints). `just app-icon` renders each by wrapping the SVG in an element with that
appearance's class, into three opaque 1024×1024 PNGs that the asset catalog lists by appearance.

**Why:** It replaces the stand-in (`35-stand-in-app-icon.md`) with the final branding, which now has a palette to
match: Paper & Ink (`84-paper-and-ink.md`). Its dark and tinted versions are drawn rather than derived, because iOS's
own dark version of a light, full-bleed icon keeps the paper background, which glares on a dark Home Screen. Recoloring
one drawing with CSS keeps a single source of truth: an edit to the bulb reaches all three. Rejected: three SVG files,
which would drift, and a transparent dark icon, since the issue asks for the bulb on ink.
