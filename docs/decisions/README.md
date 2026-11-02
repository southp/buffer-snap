# Decisions

One file per decision: why we chose what we chose. Run `just decisions` for a table sorted by date.

## Rules

- **Name the file `<issue>-<slug>.md`**, using the issue you're working on (e.g. `15-sourcekit-lsp.md`).
  One agent works on an issue at a time, so names never collide across parallel branches.
- **One decision per file.** An issue can add several.
- **Append-only.** Don't rewrite an accepted decision. To change course, add a new file and set the old one's
  `status: superseded` and `superseded_by: <new file name>`. That's the only edit an old file gets.
- **Don't add an index** to this README or anywhere else. `just decisions` builds the table from the files, so
  parallel PRs never edit the same line.

## Template

```markdown
---
date: YYYY-MM-DD
issue: N
status: accepted
---

# Short title in sentence case

**Decision:** What we do, in one or two sentences.

**Why:** The reason, including what we rejected.
```
