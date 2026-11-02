---
date: 2026-11-02
issue: 3
status: accepted
---

# Views take "now" as a parameter; snapshots pin it with the locale and time zone

**Decision:** A view that shows a relative time ("5 minutes ago") takes `now: Date` as a parameter instead of
reading the clock; its screen feeds it from a `TimelineView` that ticks every minute. Snapshot tests pass
`Capture.samplesReferenceDate`, the fixed date `Capture.samples()` is dated against, and `assertScreenSnapshot`
pins the en_US locale and a Gregorian calendar in GMT. The running app seeds `Capture.samples(relativeTo: .now)`,
so its list reads "5 minutes ago" rather than months ago.

**Why:** A view that reads `Date.now` or the machine's locale renders differently tomorrow or on another Mac, so
its snapshot would fail without any code change. We rejected `Text(date, style: .relative)` and
`Date.RelativeFormatStyle`: both read the clock themselves, so a test can't pin them. A fixed seed date alone
wasn't enough either: the running app would then show captures from months ago.
