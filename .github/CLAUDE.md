# GitHub workflows and PR review

- Every non-draft PR gets an automatic Claude review (`workflows/claude-code-review.yml`) when it's opened, marked
  ready, or pushed to. The review checks the PR against the `CLAUDE.md` files of the areas it touches and the
  acceptance criteria of the issue it `Closes`.
- Comment `@claude <request>` on a PR or issue to have Claude act on it (`workflows/claude.yml`), for example to push
  a fix to the PR branch. Only collaborators with write access can trigger it.
- Both workflows run on Linux runners without Xcode, so Claude there can't run `just`. Run `just lint` and
  `just test` locally on anything it pushes before merging.
- New PRs are prefilled from `pull_request_template.md`. Fill in every section, including snapshot changes.
- Why the workflows are set up this way: `docs/decisions/12-*.md`.
