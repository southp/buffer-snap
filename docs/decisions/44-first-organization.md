---
date: 2026-11-05
issue: 44
status: accepted
---

# Send ideas to the account's first organization, looked up each time

**Decision:** Ideas go to the first organization in `account { organizations { id } }`, in the order Buffer returns them. The ID is looked up once per pass through the queue, and never stored. A picker can come later. An account with no organization gets a failed capture.

**Why:** Buffer's data model says most people have one organization. Not storing the ID means no stale value can outlive a sign-out, so no idea can be aimed at someone else's organization, at the cost of one more request per pass, and only when there's something to send. Rejected: a picker, as nothing else in the MVP needs one.

**Known gap:** Buffer doesn't document the order. Someone with several organizations could see ideas land in a different one if the order ever changes. There's nothing to go on until someone reports it, so we use what's returned, and don't sort by ID, which would be just as arbitrary.
