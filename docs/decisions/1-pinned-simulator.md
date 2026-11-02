---
date: 2026-11-02
issue: 1
status: accepted
---

# Pin tests to the iPhone 16 simulator on iOS 27.2

**Decision:** Pin tests to the **iPhone 16** simulator on **iOS 27.2** (`SIM_DEVICE` / `SIM_OS`); `just bootstrap` creates it if missing

**Why:** Matches the developer's own phone; Xcode 27.2 has the device type but ships no iPhone 16 device, so fresh clones and CI must create it
