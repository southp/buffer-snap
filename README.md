# buffer-snap
A minimal iOS app that gives you the most frictionless way to capture any inspiration into Buffer Create on the go.

## Context
Inspiration is naughty. They come when you are lifting weights in a gym, eating the worst tofu in a fine dining, walking alongside a street carrying stuff with only one finger free, or being tripped over in a hike and seeing the most beautiful flower you've ever seen. 

At least for me, it never comes when I sit still and have all the creation tools at hands. I wish I'd have a quick way to capture the idea, even in its roughest form. Ironically, my iPhone is the only thing that's always with me even when I was tripped over in a hike. That's why I'm exploring this idea.

## How it'd work
The goal is the fewest touches between an idea and Buffer Create.

**Press, speak, done.** Press "Dictate an Idea" on the Action button, in Control Center or on the Lock Screen, or tap the mic widget on the Home Screen, and say the idea. The app stays closed: the words show live in the Dynamic Island and on the Lock Screen, and it's saved and sent once you press again, tap Stop, or pause for 3 seconds. [Testing on a real iPhone](https://github.com/southp/buffer-snap/issues/57#issuecomment-6715563614) proved it works, and [why it's built this way](docs/decisions/58-dictate-outside-app.md).

Capture starts once the phone is unlocked, which with Face ID is usually just a glance. [Testing on a real iPhone](docs/spikes/locked-capture.md) showed what iOS allows on a locked phone, and [why we don't build on it](docs/decisions/10-unlocked-capture.md).

1. Dictate without opening the app, as above. It's the main way to capture.
2. The main app provides the following.
   1. Authenticate the API access through a Buffer account, when you want ideas sent. Until then the app is in offline mode: everything stays on this iPhone and capturing works the same.
   2. The capture screen, described below.
   3. View what's being captured
   4. Manage what's being captured
      1. Resend
      2. Delete
      3. No edit
   5. There will be no sync to Buffer Create. That's not the purpose of this app.
   6. The app should keep an upper limit of how many items to be stored offline, and shuffle things off in a FIFO manner.
3. The capture screen, for typing or when you'd rather see the text first. The capture control and the BufSnap widget open it. Text has a limit of, say, 300 chars.

   | Capture | How | When |
   |---|---|---|
   | Dictated text, app closed | Press the control or the widget, speak, press again or pause | First release |
   | Dictated text, in the app | Hold the mic button, speak, release | First release |
   | Typed text | A small keyboard option, for when you can't speak aloud. No control or widget can show a text box, so this is in the app | First release |
   | Multiple pictures | One camera session: each shot adds a thumbnail to a strip in the corner, and you end it like a regular camera app. Buffer's API needs public URLs for images, so this depends on a hosting decision | Next |

4. Smart batching: captures with less than 5 minutes between them (configurable) become one Buffer Create idea.
5. Submission to Buffer Create is an offline-first experience: After each capture, the app stores the item locally. A background job submits each batch when its window ends, with exponential back-off retries. iOS doesn't guarantee a background wake-up, so a batch may wait until the app next opens, and "Send now" sends it early.


## Delivery plan
The goal is to publicly launch the v1 in the app store in time for [Buffer Commit](https://buffer.com/api/commit): the app, a write-up and a demo video are due by Nov. 13, 11:59 PM PT, and the app must be publicly available by then.

1. Scaffolding: The dev workflow is established, every component of the app is connected together, and the app is up and running on my iPhone through TestFlight or something. Nothing really work is fine — what's key here is the whole app flow can be run through even if everything is mocked and the architecture of the code base is settled. (~ Nov. 1)
2. MVP: Authentication works, capturing by dictated and typed text works, batching works, offline storage & submission job works. (~ Nov. 9)
3. v1: Submit to the app store early enough that a rejection still leaves time. (~ Nov. 10)
   * Then submit to Buffer Commit no matter what by Nov. 13
   * Everything to paste into App Store Connect, and the steps in order: [`docs/app-store/`](docs/app-store/checklist.md)
4. After that: Capturing multiple pictures.

## Development
Everything runs from the terminal through [`just`](https://github.com/casey/just) recipes, without opening the Xcode GUI.

### Prerequisites
- Xcode with the iOS platform installed and selected, plus `xcodegen`, `swiftlint` and `xcbeautify` (see [#8](https://github.com/southp/buffer-snap/issues/8)). `just bootstrap` installs any that are missing, plus `xcode-build-server`
- `just` (`brew install just`)

### Getting started
```sh
just bootstrap   # check Xcode, install missing tools, create the pinned simulator, enable git hooks
just run         # build and launch the app in the iPhone Simulator
```

### Recipes
Run `just --list` to see every recipe and what it does.

### Deploying to TestFlight
Every merge to `main` deploys on its own: once `ci` passes, a new build goes to TestFlight.

To upload from your machine, `just deploy` archives, signs and uploads a build. Your iPhone then offers it as an update in the TestFlight app.

One-time setup, after the Apple account steps in [#11](https://github.com/southp/buffer-snap/issues/11):

```sh
cp .env.example .env   # gitignored; then fill in your team ID and API key details
just deploy
```

The recipe stops before building if a value or the API key file is missing, or if the git tree is dirty, so every build matches a commit. Certificates and profiles are managed by Apple through the API key, so none live in this repo.

### Testing on your iPhone
`just device` builds, installs and launches on your phone, with no TestFlight round trip. It's how to test anything that behaves differently on a real or locked device.

One-time setup:

1. Add the phone to your developer account at [developer.apple.com/account/resources/devices](https://developer.apple.com/account/resources/devices). The build can't do this through the API key.
2. Put its identifier in `.env` as `DEVICE_ID`. `xcrun devicectl list devices` shows it.

The phone must be connected and unlocked. This replaces the TestFlight build until you install from TestFlight again.

### Editor setup
Any editor with LSP support works through Apple's `sourcekit-lsp`, which ships with Xcode. Run `just lsp` once per clone: it writes `buildServer.json` so the language server knows every target's build settings, which enables go-to-definition, references and diagnostics across files and targets.

For Neovim 0.11+ with [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig), add `vim.lsp.enable('sourcekit')` to your config.

- Run `just lsp` once per clone or worktree, and again after adding a **target**.
- A new **file** resolves after the next `just build` or `just test` (both regenerate the project first).
- The build server reads compiler flags from build logs in `build/DerivedData`, so `just clean` drops context until the next build.

### Parallel worktrees
Each git worktree gets its own simulator (`iPhone 16 (worktree: <dir>)`), so tests in different worktrees can run at the same time. After removing worktrees, run `just sims-prune` to delete their simulators.

Project conventions are in [`CLAUDE.md`](CLAUDE.md), and the reasoning behind tooling choices is in [`docs/decisions/`](docs/decisions/).
