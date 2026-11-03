---
date: 2026-11-03
issue: 27
status: accepted
---

# Don't boot the simulator early on CI

**Decision:** CI boots the simulator where `xcodebuild test` needs it, after lint, Core tests and the app build. It
doesn't start the boot early to overlap them.

**Why:** #27 proposed the overlap and measurement rejected it. A first boot sets off a swarm of system daemons and
extensions (posters, widgets, Siri, Health and more) on the runner's 3 vCPUs and 7 GB of RAM: the load average passed
400 and was still above 100 when the job ended 9 minutes after the boot, so anything sharing the machine crawls. With the boot overlapping them, `just bootstrap` went
from about 10s to 295s and lint from 3s to 35s, and the whole job took 776s against 438s in order
([overlap](https://github.com/southp/buffer-snap/actions/runs/41557104607),
[in order](https://github.com/southp/buffer-snap/actions/runs/41561028965)).
In one local try, `simctl boot --disabledJob` for 21 of the busiest jobs didn't stop them (PosterBoard and chronod
still ran), and no single job dominates, so we didn't pursue it.
