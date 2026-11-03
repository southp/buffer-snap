---
date: 2026-11-03
issue: 27
status: accepted
---

# Keep the iOS 27.2 runtime instead of an image's preinstalled one

**Decision:** The pin stays on iOS 27.2 (`24B8117`), downloaded on CI. It doesn't move to a runtime the `xcode-27`
image ships.

**Why:** #27 hoped a preinstalled runtime would avoid both the download and the slow first launch. It avoids only the
download. The image's iOS 27.1 (`24A94425`) isn't usable at all: it only runs the iPhone Duo. Its iOS 27.0 (`24A434`)
runs iPhone 16, but the `Test` step took no less time there, because the cost is the first boot of a new device, not a
just-installed runtime (`27-no-early-simulator-boot.md`).

| In order, no early boot | Runs | Download | `Test` step | Job start to end of tests |
|---|---|---|---|---|
| iOS 27.2 | 6 | 114–179s | 255–461s (median 358s) | 430–636s (median 514s) |
| iOS 27.0 | 2 | 0s | 363s, 497s | 386s, 536s |

Saving the download alone is within the noise between runs, and moving costs an older runtime than Xcode 27.2's own,
another 8 GB locally, and re-recorded snapshots: iOS 27.0 lays out list rows 1–2px differently, so the current PNGs fail
there. Revisit if the image ships 24B8117, which the download step already picks up.
