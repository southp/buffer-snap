---
date: 2026-11-09
issue: 70
status: accepted
---

# Stop is an icon on both Live Activity surfaces

**Decision:** `DictationStopButton` shows a large circle with a stop icon, labelled "Stop" for VoiceOver, in the Dynamic
Island and on the Lock Screen.

**Why:** The Dynamic Island's trailing region is too narrow for the timer and the word "Stop", which wrapped as
"Sto / p". An icon can't wrap and keeps the timer where it was. Moving the timer would have kept the word, but the other
expanded regions are either as narrow or hold the words being dictated. Keeping the word on the Lock Screen alone would
need a second look for one button, and the island's look would then have no snapshot, since only the Lock Screen view
can be rendered in a test.
