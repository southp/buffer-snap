---
date: 2026-11-10
issue: 84
status: accepted
---

# Paper & Ink is the look, drawn from one theme layer in Shared/

**Decision:** The app, its Live Activity and its widget use Paper & Ink: paper backgrounds, white cards with a 2 pt ink
outline and a 3×3 pt ink shadow with no blur, capsule buttons and chips with the same outline, pills with a 1.5 pt one,
a Tomato accent, Inter for text and Caveat Bold for big titles. Views take every color, font and shape from
`Shared/Theme.swift` and `Shared/ThemeStyles.swift`, which the app and the widget extension both compile. Each color is
a color set in `Shared/Theme.xcassets` with a light and a dark value:

| Token | Light | Dark | Used for |
|---|---|---|---|
| Paper | `#FBF7EE` | `#15140F` | Screen background |
| Surface | `#FFFFFF` | `#24221C` | Cards, chips |
| Ink | `#1A1A1A` | `#FBF7EE` | Text, outlines, offset shadows |
| Muted | `#57534C` | `#B9B2A3` | Secondary text |
| Divider | `#E4DDCD` | `#3D3A31` | Lines inside a card. Dark value chosen here: the issue gave none |
| Tomato | `#FF4D2E` | same | Primary buttons, Stop, the Failed pill |
| Tomato text | `#B8260C` | **`#FF6B4F`** | Accent text, such as "Send now" |
| Sun | `#FFE45C` | same | Pending pill, widget background, step badges |
| Mint | `#9BE8C3` | same | Submitted pill |
| Saved | `#0F6B3F` | **`#9BE8C3`** | "Saved" in the Live Activity |
| On color | `#1A1A1A` | same | Text and glyphs on Tomato, Sun or Mint |

**Why:**

- **Contrast:** two dark values from the issue fell short of 4.5:1, so they changed. Tomato text `#B8260C` measured
  2.9:1 on dark paper and 2.5:1 on a dark card; `#FF6B4F` measures 6.6:1 and 5.7:1. Saved `#0F6B3F` measured 2.8:1 on
  dark paper; Mint measures 12.9:1 there, and 14.7:1 on the Dynamic Island's black. Everything else passes as given: ink
  on Tomato is 5.3:1 (white would be 3.3:1, so text on Tomato is ink), muted on paper 7.2:1 light and 8.8:1 dark.
- **On color:** Tomato, Sun and Mint keep their value in dark mode, while ink turns cream, which can't be read on them.
  Text on them uses a separate token that stays ink. The widget stays Sun in dark mode, so its outlines use it too.
- **Color sets, not a dynamic `UIColor`:** WidgetKit archives a widget's and a Live Activity's views and renders them
  outside the extension's code, so a color whose light and dark values come from a closure isn't guaranteed to resolve
  there. A named color set is data in the bundle, which the system resolves for either appearance, as it does in the
  app. One catalog in `Shared/` reaches both bundles, the same way `Shared/`'s intents reach both targets.
- **Cards a row at a time:** a `List` keeps swipe-to-delete, but gives each row its own background, so `CardBackground`
  draws a row's part of its card (top, middle, bottom or whole) and cuts off the open edges. The batching setting's
  choices became rows of plain buttons with a checkmark, since an inline `Picker`'s rows ignore a row background. They
  call the same `onChoose` and say which one is selected to VoiceOver.
- **Circular capsules:** on iOS 27, the outline of a `.continuous` capsule drew stray bars beside its ends, so capsules
  are `.circular`.
- **The system's glass is off behind the toolbar's chips** (iOS 26 and later), or it would sit around their outlines.
  The Account menu is styled as a button, which keeps its chip in the toolbar, where a custom label lost it. VoiceOver
  now calls it a pop-up button.
- **The Live Activity has no outline or shadow:** the system clips it to its own shape, so neither can be drawn outside
  it. It sits on paper instead, with the Tomato Stop. The Dynamic Island keeps the system's black and white, in Inter.

Rejected: keeping the system's grouped list look with Paper & Ink colors, which loses the outlines that make it Paper &
Ink; and a `ScrollView` of cards, which loses swipe-to-delete.
