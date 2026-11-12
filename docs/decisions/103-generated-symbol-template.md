---
date: 2026-11-12
issue: 103
status: accepted
---

# A script generates the dictate symbol's SF Symbols template

**Decision:** `docs/design/control-symbol.svg` is the symbol's only source: a stroked drawing in the app icon's
coordinates. `just control-symbol` runs `docs/design/control-symbol.swift`, which outlines and merges the strokes
with CoreGraphics and writes an SF Symbols 3.0 template with all nine weights at all three scales into the
symbolset. Weights scale the stroke widths (a cut-out more gently, so it stays open); scale sizes and side bearings
match `lightbulb.fill`.

**Why:** It keeps the dev loop in the terminal (root `CLAUDE.md`) and works like `just app-icon`: edit one drawing,
regenerate, commit both. The SF Symbols app has no command line, so exporting from it would be a manual step that
nobody could repeat the same way, and a hand-drawn template needs each of 27 glyphs redrawn after any change. All 27
are written out rather than three masters for Xcode to interpolate, so each weight is exactly what the script drew.
Rejected: a 3-master variable template (its paths must match point for point, which CoreGraphics' boolean
operations don't promise), and a plain SVG image asset, which wouldn't follow the control's weight and scale.
