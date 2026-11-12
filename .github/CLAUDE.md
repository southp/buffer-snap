# GitHub workflows and PR review

## CI (`workflows/ci.yml`)

- Every PR and every push to `main` first runs `changes`, a quick Linux job that lists the changed files. Then the
  `ci` job runs `just bootstrap`, `just lint`, `just test`, the same recipes you run locally. Branch protection on
  `main` requires `ci` to pass. A newer push to a PR cancels its older run; runs on `main` never cancel each other.
- **Docs-only skip:** when every changed file is on the safe list (`*.md`, `docs/*`, `site/*`, `LICENSE`,
  `workflows/claude.yml`, `workflows/claude-code-review.yml`), `ci` and `deploy` are skipped, so no macOS runner
  starts, on a PR or on `main`. A skipped `ci` counts as passed, so the PR stays mergeable. A PR diffs its merge
  commit against the base; a push to `main` diffs against the commit `main` was at before. Everything else takes the
  full path, as does any case where the changed files are unknown. The "Choose the path" step in `changes` prints
  its decision and the file list. The list is an allowlist in that step: add to it only what can't affect the app or
  its snapshots (`docs/decisions/102-docs-only-skips-ci.md`).
- It runs on the `xcode-27` image with Xcode 27.2 and, if the image has no runtime for the pinned simulator,
  downloads iOS runtime build `SIM_RUNTIME_BUILD` (`docs/decisions/6-*.md`). When you bump the pin, change `SIM_OS` and
  `SIM_RUNTIME_BUILD` in `justfile` and the Xcode path in `ci.yml` together (`xcrun simctl runtime list` shows your
  build), then re-record every snapshot.
- When it fails, the run's `test-artifacts` artifact has `build/snapshot-failures/` (the PNG CI rendered) and the
  `.xcresult` bundles: `gh run download <run-id> -n test-artifacts -D <dir>`. Compare that PNG with the reference in
  `AppTests/__Snapshots__/` before deciding anything. For the reference, failure and difference PNGs side by side,
  run `xcrun xcresulttool export attachments --path <dir>/DerivedData/Logs/Test/<name>.xcresult --output-path <out>`
  (`manifest.json` there names each file).
- The full path's cost is the simulator's first boot, which saturates the runner for minutes
  (`docs/decisions/27-no-early-simulator-boot.md`). Don't run other work alongside it.
- Don't add a matrix, or per-change test selection beyond the docs-only skip. Caching is out of scope so far (#27).
- Renaming the `ci` job breaks the required check; change the branch rule with it.

## Deploy (`deploy` job in `workflows/ci.yml`)

- Each push to `main` that passes `ci` runs `just deploy`, so every merge that changes more than the safe list reaches
  TestFlight. A docs-only merge skips `ci`, and so skips `deploy` too. PRs never run this job and never see its secrets.
- If a code merge's run on `main` is dropped (see below) and the merge after it is docs-only, nothing deploys the
  code until the next full-path merge. Re-run the dropped commit's workflow from the Actions tab to ship it sooner.
- The recipe archives unsigned, so CI needs no certificate of its own (`docs/decisions/9-unsigned-archive.md`).
- It needs the repo secrets `ASC_KEY_P8` (the `.p8` file's contents), `ASC_KEY_ID`, `ASC_ISSUER_ID` and `DEVELOPMENT_TEAM`.
- Runs on `main` go one at a time, in order. GitHub keeps only one waiting run per group, so with three quick merges the
  middle one is skipped: its commit is still tested and deployed as part of the newest (`docs/decisions/9-deploy-on-merge.md`).
- A failed `deploy` doesn't block merging. The next merge deploys everything, or re-run the job from the Actions tab.

## Site (`workflows/pages.yml`)

- `site/` is public at `https://southp.github.io/buffer-snap/`, published when it changes on `main`. It holds what must live at a public URL, such as the OAuth return page. Never put anything private there.
- `site/privacy/` is the privacy policy that Buffer's app client and the App Store link to. Update it whenever the app starts handling new data, such as pictures.
- `site/oauth/` is Buffer's registered redirect URI. Buffer compares it character for character, so moving it means updating the app client too (`docs/decisions/43-oauth-redirect-page.md`).

## Screenshots and screencasts

Any PR that changes what a user can see shows the change in its "Screenshots" section, so a reviewer can judge it
without building the app. Include a screenshot of each state that changed. Add a screencast for a flow, an animation,
or anything that crosses between the app and the widget. Snapshot PNGs in the diff don't replace these: they show one
view with fixture data.

**Capture** from the PR's head, after your last rebase, on your worktree's simulator. Recapture if a later push changes
what's on screen. Each area's `CLAUDE.md` says how to drive its screens.

```sh
UDID="$(just _sim-udid)"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl io "$UDID" screenshot shot.png
xcrun simctl io "$UDID" recordVideo --codec=h264 --force flow.mp4   # Stop with Ctrl-C (SIGINT) to write the file

# GitHub only plays video uploaded through its web page, so make a GIF to show inline. Needs ffmpeg.
ffmpeg -i flow.mp4 -vf "fps=10,scale=300:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" flow.gif
```

UI automation can time out right after a clean boot, while the machine is saturated. Wait for the load to settle.

**Check every frame before publishing: this repo is public.**

- A freshly erased simulator takes the host's language. To record in English, run these, then reboot it:
  `xcrun simctl spawn "$UDID" defaults write "Apple Global Domain" AppleLanguages -array en-US` and
  `xcrun simctl spawn "$UDID" defaults write "Apple Global Domain" AppleLocale -string en_US`.
- Stock widgets can show the host's region. Maps did, and `simctl location` didn't change it, so remove such widgets.
- List in the PR whatever you staged (status bar, removed widgets, cuts in the video).

**Host** the files on the `pr-media` branch, in `pr-<N>/`. Never commit media to your issue branch: with rebase merges,
the binaries would stay in `main`'s history forever. Hosting needs the PR's number, so open the PR as a draft first and
mark it ready once the media is in: drafts aren't reviewed, so the review then sees the media. These steps use a
temporary index, so they don't touch your worktree:

```sh
N=<PR number>
git fetch origin pr-media
export GIT_INDEX_FILE="$(mktemp -u)"
git read-tree FETCH_HEAD
files=(shot.png flow.gif flow.mp4)   # Only the files you have
for f in "${files[@]}"; do
    git update-index --add --cacheinfo "100644,$(git hash-object -w "$f"),pr-$N/$(basename "$f")"
done
tree="$(git write-tree)"
rm -f "$GIT_INDEX_FILE"; unset GIT_INDEX_FILE
commit="$(git commit-tree "$tree" -p FETCH_HEAD -m "Docs: Add the media for PR #$N")"
git push origin "$commit:refs/heads/pr-media"
echo "https://raw.githubusercontent.com/southp/buffer-snap/$commit/pr-$N/"
```

- Link that commit-pinned URL with `<img src="..." width="300" alt="...">`. A link to the branch would move with it.
- If the push is rejected, another PR got there first: start again from `git fetch`.
- Only edit the PR body once the push has succeeded. New URLs can return 404 for about a minute, so then open the PR
  page and check that everything displays.
- Never delete `pr-media`. Merged PRs still link to it.

## Claude review

- Every non-draft PR gets an automatic Claude review (`workflows/claude-code-review.yml`) when it's opened, marked
  ready, or pushed to. The review checks the PR against the `CLAUDE.md` files of the areas it touches and the
  acceptance criteria of the issue it `Closes`.
- Comment `@claude <request>` on a PR or issue to have Claude act on it (`workflows/claude.yml`), for example to push
  a fix to the PR branch. Only collaborators with write access can trigger it.
- Both Claude workflows run on Linux runners without Xcode, so Claude there can't run `just`. Run `just lint` and
  `just test` locally on anything it pushes before merging.
- New PRs are prefilled from `pull_request_template.md`. Fill in every section, including snapshot changes and screenshots.
- Why the workflows are set up this way: `docs/decisions/12-*.md`.
