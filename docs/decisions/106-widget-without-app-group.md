---
date: 2026-11-17
issue: 106
status: accepted
---

# The widget extension has no App Group

**Decision:** `Widget/BufferSnapWidget.entitlements` no longer lists `group.me.southp.buffersnap`. Only the app is in the
App Group, which still holds `captures-v2.json`. The file stays, with no entitlements in it, because `just deploy` ad hoc
signs the extension with it (`9-unsigned-archive.md`). Everything else in `81-only-the-dictate-widget.md` stands:
Dictate an Idea is the only widget, the captures stay where they are, and the target keeps its names. This supersedes
`81-only-the-dictate-widget.md`, which kept the entitlement.

**Why:** Nothing compiled into the extension opens the group's container: not `Widget/`, not `Shared/`, and not the
parts of BufferSnapCore it uses (`DictationStatus`, `HandsFreeDictationSession.PressResult`). An entitlement that
nothing uses is access the extension doesn't need. Decision 81 kept it because only a signed build on an iPhone can
check a signing change. The owner checks that on the 1.1.1 TestFlight build: the control, the Home Screen widget and the
Live Activity still work (#134's smoke test). Rejected: deleting the file and `CODE_SIGN_ENTITLEMENTS`, which would mean
changing the deploy recipe too, for no gain.
