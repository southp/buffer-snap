---
date: 2026-11-02
issue: 13
status: accepted
---

# Record snapshots only on request, and let recording pass

**Decision:** `just test` never records (`.never`): a missing reference PNG fails the test. `just snapshots-record`
(`SNAPSHOT_RECORD=1`) records every snapshot (`.all`) and passes, because writing PNGs is what it was asked to do.

**Why:** The library's default, `.missing`, writes a new reference during a normal test run and passes on the next
run, so an unreviewed PNG can slip into a commit. Its record mode fails every test it records, which would make
`just snapshots-record` exit non-zero on success and hide real failures among the expected ones.
