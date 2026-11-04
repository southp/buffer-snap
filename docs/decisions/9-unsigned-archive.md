---
date: 2026-11-04
issue: 9
status: accepted
---

# Archive unsigned, so deploying creates no development certificates

**Decision:** `just deploy` archives with `CODE_SIGNING_ALLOWED=NO`, ad hoc signs each target with its entitlements, and
leaves the real signing to the export step, where Apple's cloud-managed distribution certificate signs it.

**Why:** A signed archive needs a development certificate with its private key on the machine. A fresh CI machine has
neither, so its first test run created a new certificate on the Apple account, and every run would have added another.
An unsigned archive alone drops the App Group, because export reads entitlements from each target's signature; the ad
hoc signatures carry them through, and the exported app and widget both had the group and an Apple Distribution
signature. Rejected: storing a certificate as a repo secret (#9's fallback), which is another secret to guard and renew
every year. The cost is that the recipe has to list each extension's entitlements. It stops on an extension it doesn't know, because
the linker's own signature would otherwise let it through without its entitlements.
