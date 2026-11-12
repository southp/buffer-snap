---
date: 2026-11-12
issue: 103
status: accepted
---

# The dictate symbol is the Doodle Bulb, filled, with its filament cut out

**Decision:** The Dictate an Idea control and the Home Screen widget draw `bufsnap.dictate`, a custom SF Symbol in
`Shared/Theme.xcassets`: the app icon's bulb as a solid shape, its sound-wave filament cut out of it, on two base bars.
The Live Activity keeps its system symbols (`mic.fill`, `mic.slash`, Stop).

**Why:** `mic.fill` looked like every other mic control, and a control only takes a one-color template symbol, so the
full-color icon couldn't be used. Of three candidates drawn at Control Center size (this one, the same bulb with the
icon's four rays, and an outlined bulb), the filled bulb matches the filled system symbols beside it in Control Center
and stays legible at the Lock Screen's small size. The rays shrank the bulb to fit the extra width, and the outline
bulb's filament crowded its outline at the Lock Screen's size. The cut-out filament still says "speak" and, on the widget's
Tomato circle, shows Tomato through like the icon's red filament. The Live Activity's symbols tell listening apart
from a refused mic, which a brand symbol can't.
