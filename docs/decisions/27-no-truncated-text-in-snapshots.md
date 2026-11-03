---
date: 2026-11-03
issue: 27
status: accepted
---

# Keep truncated text out of snapshot fixtures

**Decision:** Snapshot fixtures use text that fits, so nothing renders with an ellipsis. Test truncation some other way
if it matters. Precision stays at 1.0 pixels and 0.98 perceptual.

**Why:** On #25, CI drew the truncated second line of a two-line `Text` exactly 1px higher than a local run, with every
other pixel identical, including the first line of the same `Text`. That failed a strict snapshot on the same runtime
build (24B8117). Lowering precision would hide real changes of the same size.

The cause is the host, by elimination, though we couldn't test it directly:

- **Not the Xcode version, as far as we can test:** Xcode 27.2 RC and Xcode 27.0 rendered byte-identical PNGs on one
  runner ([run](https://github.com/southp/buffer-snap/actions/runs/41562831136)). That was on iOS 27.0, and the image has
  no 27.2 release build to try, so RC against release itself is inferred.
- **Not load or timing:** the same runner rendered the same bytes during and after the first-boot load (same run).
- **Not a fresh simulator:** a newly created local simulator matched the local reference.
- **What's left:** CI is a macOS 27.0.1 VM, local is macOS 27.2 on Apple Silicon hardware. The difference is stable on
  each side, not a flake.

Untruncated wrapped text isn't known to be affected: only the truncated line moved. If a wrapped fixture fails the same
way, treat it like this one.
