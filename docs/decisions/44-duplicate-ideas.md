---
date: 2026-11-05
issue: 44
status: accepted
---

# Prefer a rare duplicate idea to a lost one

**Decision:** When no answer comes back from `createIdea`, the capture stays pending and is sent again, even though Buffer may already have created the idea. So a lost response can leave two copies of an idea in Buffer Create. We shrink how often that can happen, and don't try to rule it out.

**Why:** A lost idea is the failure this app exists to prevent, and a duplicate takes one delete. The app can't tell the two apart: `createIdea` has no idempotency key, and looking for the idea first needs `ideas:read`, a scope we don't ask for. The moment a connection drops mid-request is common on a phone, so stopping there would mean tapping Resend in everyday use, and the issue asks for no further action.

What keeps duplicates rare:

- **One send at a time:** launch, foreground and connectivity can all fire together, and only one pass runs.
- **A success is written down at once, and only then does the next send start.** If that write fails, the capture stays out of the running in memory, as sending it again would be a certain duplicate, not a possible one. Only a crash in that moment can still send it again.
- **A send isn't cancelled when a background task runs out of time**, and the app asks iOS for a little more time when it goes to the background, so "save and lock the phone" normally finishes.
- **A limit on server failures:** a 5xx or `UnexpectedError` may come after the work is done. After 5 of them a capture shows as failed, so a server stuck in that state can't fill someone's Buffer. A dropped connection has no limit, because offline can last days.
- **A type we don't recognize in `createIdea`'s response counts as failed, not as "try again".**

Rejected:

- **Marking the capture failed on a lost response, for the user to decide:** it's the honest answer, but they can't tell either, and it asks for a decision on an ordinary network blip.
- **Adding `ideas:read` to look for the idea before sending again:** it's a wider grant to ask people for, and it would only work by matching text, which two real ideas can share.
- **`createContentItemDraft`, which has a `correlationId` for exactly this:** it's marked experimental ("can change without a deprecation period"), and it creates a draft, not an idea. Worth another look if Buffer adds the same to `createIdea`.
