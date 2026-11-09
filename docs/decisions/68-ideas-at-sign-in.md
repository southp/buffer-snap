---
date: 2026-11-09
issue: 68
status: accepted
---

# Ask once before sending what was waiting at sign-in

**Decision:** Everything pending is held before a sign-in starts, as `44-hold-captures-at-sign-in.md` did, and again once it's done, for anything saved while Buffer's page was open. A sign-in that ends with held ideas asks once: "Send N ideas to this account?" (`AppModel.ideasToConfirm`, counted in batches, as each is one idea). Yes reopens them all and sends them. A sign-in that doesn't happen, or a sign-out or session Buffer ended, puts them back to waiting.

**Declining:** "Not Now" leaves them held, with Resend on each batch and "Held at sign-in" in the list. Nothing is lost, and the question doesn't come back until the next sign-in.

**Why:** Captures made while signed out have no owner, and neither do captures left waiting by a sign-out or a session Buffer ended, so #44's protection still applies: one person's ideas mustn't reach another's Buffer by themselves. Holding keeps the mechanism that already survives a crash between a sign-in and its first send: the hold is written before the session exists. What changes is that someone gets asked instead of having to discover Resend.

A crash or a launch before the answer leaves them held, exactly as declining does: safe, visible, with Resend, and not asked twice. Rejected: a remembered "ask again" flag, which has to be kept in step with the store to save a tap after a crash. Also rejected: asking per capture, which reads as many questions about what's one decision.

A cancelled sign-in closes open batches, so a capture made right after it starts a new one. It's a rare split that costs one extra idea, and it keeps the hold at the one point that's crash-safe.
