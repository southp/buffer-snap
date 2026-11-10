# Screenshots

```sh
just store-screenshots
```

It builds the app, then saves every screenshot, at both sizes, in `build/store-screenshots/`. Upload them in App Store
Connect → the version page → **Previews and Screenshots** → iPhone, in the order of their file names.

## Sizes

Checked against Apple's
[screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
on November 8, 2026:

| Folder | App Store Connect's slot | Simulator | Pixels | Needed? |
|---|---|---|---|---|
| `6.3-inch/` | iPhone with Dynamic Island (medium display) | iPhone 17 Pro | 1206×2622 | **Required** |
| `6.9-inch/` | iPhone with Dynamic Island (large display) | iPhone 17 Pro Max | 1320×2868 | Recommended. Without it, App Store Connect scales the 6.5" slot's |

The 6.5" slot (iPhone with Face ID, large display) is required only when no 6.9" screenshots are given, so uploading
the 6.9" ones covers it. App Store Connect scales these down for every smaller iPhone. iPhone Duo screenshots become
required for builds on the iOS 27.1 SDK or later from April 2027, not yet.

## What each one shows

| File | Shows | Taken from |
|---|---|---|
| `1-dictate.png` | "Press. Speak. Done.": the Live Activity listening, then saved | Snapshot-test renders on a plain background |
| `2-captures.png` | The capture list, with a batch waiting to send and two sent | The app on the simulator, with sample captures |
| `3-widget.png` | "One press away": the Dictate widget | Snapshot-test render on a plain background |
| `4-batching.png` | The batching setting | The app on the simulator |

- **The simulator can't show a Live Activity or a widget with real content,** so 1 and 3 put the snapshot tests'
  renders (`AppTests/__Snapshots__/DictationActivityViewTests/`, `WidgetViewTests/`) under a caption. They're
  the same SwiftUI views the iPhone draws. A real Lock Screen photo from an iPhone would be better if there's time.
- **The frame is Paper & Ink,** like the app: a Caveat caption on paper, set in the app's own font files from
  `Shared/Fonts/`, with each render outlined in ink and given an ink offset shadow.
- **The app runs its Debug build** with `-mockAuth signedIn`, so it's past sign-in without a Buffer account, and with
  the mocked Buffer that goes with it, so nothing is sent anywhere. Sample captures are written into the App Group
  file before launch, dated from the moment it runs.
- **Each size has its own simulator** (`iPhone 17 Pro Max (worktree: …)` in a worktree), in light mode, in English,
  with full bars and the status bar showing the real time, so it agrees with the list's "Sends at".
- PNGs have no alpha channel, which App Store Connect rejects.

## Retaking them

Run the command again after any change to what these screens show, such as #46's list and empty state. Captions are in
the `store-screenshots` recipe in `justfile`, and the sample captures in its `seed` function.

The recipe needs Google Chrome and ffmpeg, as `just app-icon` does, and AXe to tap through the app: the one
XcodeBuildMCP bundles (`App/CLAUDE.md`), or `brew install cameroncooke/axe/axe`. Right after a simulator's first boot,
AXe can time out: the recipe retries, and running it again works once the machine settles.
