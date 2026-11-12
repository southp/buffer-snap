# Widget (Snapper)

Notes for working on the `BufferSnapWidget` extension. Repo-wide rules are in the root `CLAUDE.md`; the data flow is
in [`docs/architecture.md`](../docs/architecture.md).

## What the extension holds

| Surface | Type | Runs |
|---|---|---|
| Action button, Control Center, the Lock Screen's bottom buttons | `DictateIdeaControl` | `DictateIdeaIntent` |
| Home Screen and Today View (`systemSmall`) | `DictateWidget`, drawn by `DictateWidgetView` | `DictateIdeaIntent` |
| Lock Screen and Dynamic Island, while dictating | `DictationLiveActivity`, drawn by `DictationActivityView` | Stop: `StopDictationIntent` |

`SnapperWidgetBundle` is the extension's `@main` and lists them all. Nothing captures in this extension's process: every
press runs in the app's process, with the app closed. Nothing here reads or writes the captures either, and
`DictateWidget`'s face never changes, so nothing needs to reload its timeline.

## Dictating without opening the app

- **`DictateIdeaIntent` and `StopDictationIntent` live in `Shared/`.** They're `LiveActivityIntent`s, so the system runs
  them in the app's process, where they call `HandsFreeDictationSession` through `onRun`. The hook stays
  `nil` here (`docs/decisions/58-dictate-outside-app.md`).
- **The app owns the Live Activity**: `LiveActivityDictationDisplay` starts, updates and ends it. This extension only
  draws `DictationActivityAttributes`, whose content state is Core's `DictationStatus`.
- **Only a listening status shows the timer and Stop.** A timer left in any other state kept running after "Saved" on
  the #57 spike. `DictationActivityView` takes `timerPausedAt` so a snapshot can freeze the timer.
- **There's no Lock Screen widget, on purpose.** On an iPhone, an `accessoryCircular` `Button(intent:)` only opened the
  app, even with `DictateIdeaIntent`. The way to dictate from the Lock Screen is the control, in its bottom buttons
  (`docs/decisions/81-only-the-dictate-widget.md`).
- **Check it on an iPhone** (`just device`): listening with the app closed, the background audio and the Lock Screen
  are what the #57 spike proved there, and none of it is something the simulator can show.

## The dictate symbol

The control and the widget's face draw `bufsnap.dictate`, a custom SF Symbol: the Doodle Bulb filled, with its
sound-wave filament cut out, on two base bars. Controls only take one-color template symbols, which the system tints,
so it's a symbol rather than the app icon. The Live Activity keeps its system symbols: they describe a state, not the
brand (`docs/decisions/103-filled-bulb-dictate-symbol.md`).

- **Source:** `docs/design/control-symbol.svg`, a 100×100 drawing whose comment says which SVG it accepts.
- **Regenerate:** edit the SVG, run `just control-symbol`, and commit both the SVG and
  `Shared/Theme.xcassets/bufsnap.dictate.symbolset/bufsnap.dictate.svg`. Then re-record the widget's snapshots
  (`just snapshots-record`) and read them. Never edit the generated template by hand.
- **How:** `docs/design/control-symbol.swift` outlines the strokes with CoreGraphics into all nine weights at all three
  scales of an SF Symbols template (`docs/decisions/103-generated-symbol-template.md`). Weights scale the stroke
  widths; scale sizes and side bearings match `lightbulb.fill`.
- To check it compiled: `xcrun assetutil --info <app>/PlugIns/BufferSnapWidget.appex/Assets.car` lists 27
  `Vector Glyph` renditions of `bufsnap.dictate`.
- Draw it with `Image(decorative:)`, next to text that says what it does or in a button labeled with it, like the
  widget's face. A plain `Image("bufsnap.dictate")` makes VoiceOver read the asset's name.
- **Tinted and clear Home Screens** draw a widget in one color, by opacity alone, so a symbol on a filled shape
  disappears. `DictateWidgetView` checks `widgetRenderingMode` and draws its circle as an outline there;
  `WidgetViewTests.dictateTinted` snapshots that branch.

## Gotchas

- **Don't use XcodeGen's `entitlements:` key without `properties`:** `just gen` then overwrites the file with an empty
  one, and `containerURL(forSecurityApplicationGroupIdentifier:)` returns nil ("client is not entitled" in the log).
  The targets set `CODE_SIGN_ENTITLEMENTS` to a committed file instead.
- **No per-target team, signing or version settings.** They come from the project level, so the widget's build number
  always matches the app's, which App Store Connect requires.
- `Widget/Info.plist` holds only `NSExtension` and `UIAppFonts`, which have no `INFOPLIST_KEY_` settings; the rest is
  generated.
- **Draw with the Paper & Ink theme in `Shared/`**, as the app does. The extension is a process of its own, so it
  bundles its own copy of the fonts and color sets (`Shared/Fonts/`, `Shared/Theme.xcassets`). The widget stays Sun in
  dark mode, so what's drawn on it is `Theme.onColor`, never `Theme.ink`.
- **A test can't import an extension.** `AppTests/target.yml` compiles the widget's stateless views and `Shared/` into the
  test target, so a new view needs a line there.

## Seeing it run

`AppTests/WidgetViewTests.swift` snapshots the widget's face, and `AppTests/DictationActivityViewTests.swift` each
state of the Live Activity on the Lock Screen. To see it for real, run the app (`just run`) and add the widget
from the gallery. The control also works on the simulator: open Control Center, tap the + at the top left, then
"Add a Control".

Driving SpringBoard with the AXe binary from `App/CLAUDE.md` takes different commands than driving the app. These are
what worked on the iOS 27.2 simulator:

| To | Use |
|---|---|
| Tap a widget button or a menu item | `axe touch -x <x> -y <y> --down --up --delay 0.15 --udid "$UDID"` (`axe tap` didn't reliably register) |
| Enter edit mode | The same `axe touch`, with `--delay 2.0` on an empty spot |
| Change Home Screen page | `axe drag --start-x 360 --start-y 600 --end-x 40 --end-y 600 --udid "$UDID"` (`axe swipe` didn't page) |
| Open the Edit menu, then the gallery | Enter edit mode, `axe touch` Edit, wait until `axe describe-ui` lists Add Widget, then `axe touch` it. A touch sent before the menu is ready closes edit mode and lands on whatever is underneath |
| Open Control Center | `axe drag --start-x 340 --start-y 5 --end-x 340 --end-y 500 --udid "$UDID"` |
| Leave the app without killing it | `xcrun simctl launch "$UDID" com.apple.Preferences`, then `xcrun simctl terminate "$UDID" com.apple.Preferences` (`axe button home` and a bottom-edge swipe didn't leave it). This lands on the first page |
