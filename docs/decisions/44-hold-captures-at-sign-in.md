---
date: 2026-11-05
issue: 44
status: accepted
---

# Hold pending captures when a sign-in starts

**Decision:** Before any sign-in starts, every pending capture becomes failed. It shows as Failed with Resend, and only a tap on Resend sends it, to whichever account is signed in by then. If those captures can't be marked, the sign-in doesn't go ahead and the sign-in screen says it failed.

**Why:** Sign-out keeps captures, so without this, one person's pending captures would upload by themselves to the next person's Buffer. Every way to another account goes through a sign-in, whether it follows a sign-out, a session Buffer ended, or a Keychain that couldn't be read at launch, so that's the one place to check. Doing it before the sign-in, not after, means a crash in between can't leave a new session with captures still pending. The queue reads the store after getting each token, so a pass in flight can't send a held capture with the new token either. A capture already on its way when the hold happens went on the old session, so it ends up Submitted.

**What it costs:** The same person signing back in after a session ended has to tap Resend on what was pending, as does someone who opens Buffer's page and then cancels. That's rare, and it's visible and loses nothing.

Rejected:

- **Remembering which account each capture belongs to:** with `account { id }`, the same person's captures could go on by themselves. But it needs a saved account ID, a rule for captures whose owner was never learned (offline since sign-in), and a way to ask about the rest. All of that is to save a tap in a rare case. It's the next step if this turns out to annoy people.
- **Deleting pending captures on sign-out:** it loses ideas, the one thing this app mustn't do, and a session ending by itself wouldn't be covered.
- **A separate "held" status:** a new status for the list and its snapshots to explain, when Failed with Resend already means "this won't go until you say so".
