---
date: 2026-11-05
issue: 45
status: accepted
---

# A changed window applies at once to whatever is still open

**Decision:** The queue asks for the window each time it plans, and changing the setting makes it plan again straight away. So the new window applies to every capture that hasn't closed into a batch, counted from each capture's own timestamp, and closed batches don't change.

| Change while a batch is open | What happens |
|---|---|
| Longer | It waits longer, and captures now within the window of each other join up |
| Shorter | It goes as soon as the new window has passed. Captures further apart than the new window split into separate ideas |
| Off | Each capture goes at once, as its own idea |

**Why:** It takes no extra state, and it does what the setting says: someone who turns batching off has asked for each capture to go by itself. Nothing has reached Buffer at that point, so nothing can be duplicated or lost, and the list shows the new grouping straight away. Rejected: keeping an open batch together under the window it started with, which would need the batch stored from its first capture and a remembered window for each, only to avoid a split that follows from the setting someone just chose.
