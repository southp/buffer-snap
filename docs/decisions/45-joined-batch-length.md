---
date: 2026-11-05
issue: 45
status: accepted
---

# Put no limit on a joined batch

**Decision:** The 300-character limit stays per capture, and a batch's joined text has no limit of its own. If Buffer refuses it, the batch shows as Failed.

**Why:** Buffer doesn't document a limit for an idea. `IdeaContentInput.text` is a plain `String` in the API reference, and the [character limits guide](https://developers.buffer.com/guides/character-limits.md) is about posts: the limits are per network, checked "before a post is scheduled or published". An idea isn't tied to a network. `createIdea` can answer `InvalidInputError`, which `44-what-gets-retried.md` already turns into Failed, so a limit we don't know about costs a visible failure and no lost text. Any number we picked would be a guess, and splitting a batch to fit it would undo what the batch is for. Rejected: capping at a network's limit, which one network's limit can't justify, as the idea may be for another.

**Known gaps, neither testable without a real account:**

- Whether Buffer has an unwritten limit on an idea. A batch would need about 17 captures of the full 300 characters to pass even Facebook's 5,000.
- A joined idea can be longer than some networks allow, such as X's 280 on the free plan or Bluesky's 300, which only one or two captures can reach. Buffer's composer checks that when someone turns the idea into a post, and it's theirs to edit by then.
