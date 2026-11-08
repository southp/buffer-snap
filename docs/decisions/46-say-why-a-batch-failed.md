---
date: 2026-11-08
issue: 46
status: accepted
---

# Keep why a capture failed, and say what would help

**Decision:** A failed capture keeps a reason, `Capture.failure`: `refused` (Buffer said no for good), `serverTrouble`
(Buffer kept failing, `SubmissionQueue.maxServerFailures` times) or `heldAtSignIn` (`44-hold-captures-at-sign-in.md`).
The store saves it with the failed status and clears it with any other, so Resend forgets it. A failed batch's header
says which it was and what to do:

| Reason | Header | What it adds |
|---|---|---|
| `refused`, more than one capture | Buffer refused this idea | Resend will likely fail again. Delete some of its captures, then resend the rest |
| `refused`, one capture | Buffer refused this idea | Resend will likely fail again |
| `serverTrouble` | Not sent: Buffer kept failing | Nothing: Resend is the fix |
| `heldAtSignIn` | Held at sign-in | Saved before this sign-in. Resend sends it to the account signed in now |
| none (failed before this) | Not sent | Nothing |

Resend stays on every failed batch.

**Why:** A refused batch was the one place where the obvious tap, Resend, can't work: Buffer refuses the same text again,
and only deleting captures changes it (`45-resend-and-delete.md`). The list said "Not sent" whatever happened, so nobody
could tell. The reason has to be saved, not worked out: a held batch and a refused one look the same in the store, and
the list reads the store after a relaunch.

The copy says "likely" and "some of its captures" because we don't know Buffer's rule (`45-joined-batch-length.md`), and
a refusal can be for something else, such as an account limit, where deleting won't help either. It's still the only
thing the app can offer. Resend stays because the refusal might have been a mistake on Buffer's side, and taking the
button away would leave nothing to try.

The reason is optional in the file, so captures saved before this read as failed with no reason. It isn't a new status
(`44-hold-captures-at-sign-in.md` rejected that), only an explanation of `.failed`.
