---
date: 2026-11-05
issue: 10
status: accepted
---

# Start capture after the phone is unlocked

**Decision:** Every capture path opens the app, so the phone must be unlocked first. The paths are a control (Action button, Control Center, Lock Screen) and a widget button (Today View, Home Screen, Lock Screen).

**Why:** The goal is the fewest touches between an idea and Buffer Create, and with Face ID an unlock is usually just a glance. Rejected: capturing on a locked phone. [The spike](../spikes/locked-capture.md) got text and photos working in a Lock Screen capture extension, but a text box there sits on what Apple describes as a camera experience, with no word on whether App Review accepts it. It also can't reach the network or shared storage, and it adds a target.
