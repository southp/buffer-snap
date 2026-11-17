---
date: 2026-11-17
issue: 144
status: accepted
---

# Appearance is an app-only choice in the account menu, kept on this iPhone

**Decision:** People choose System (the default), Light or Dark under the account menu's Appearance, a `.menu`
`Picker` between Batching and How to Add that checks the current choice. It changes only the app: Dictate an Idea, the
widget and the Live Activity keep following iOS. The choice is stored under `appearance` in the app's standard
`UserDefaults`, as `Appearance`'s raw value, and `BufferSnapApp` applies it with `.preferredColorScheme` on the
`WindowGroup`'s content, `nil` for System.

**Why:**

- **App only:** WidgetKit draws the control, the widget and the Live Activity outside the app, with the system's
  appearance, and no API lets an app choose theirs. The support page says so.
- **A submenu, not a screen:** three choices fit in a menu, and a `.menu` picker shows which one is on with a
  checkmark, as iOS's own menus do. A screen like Batching's would be a tap and a back button for one choice. The
  submenu's own symbol is `circle.lefthalf.filled`, Apple's symbol for appearance, which System's choice also uses.
- **Standard `UserDefaults`, not the App Group:** only the app reads it; the extension doesn't need it, and it left the
  App Group in #106. It isn't account data, so signing out keeps it. An unknown stored value reads as System
  (`Appearance(storedValue:)`), so a value from a later version can't leave the app stuck.
- **On the window's content, not on `RootView`:** there, the sheets (How to Add) and alerts (the dictation notice) it
  presents follow it too. `RootView`'s snapshot test renders `RootView` in a set appearance, and would have taken
  whatever the test host's simulator had stored.
- **`.preferredColorScheme(nil)` is enough:** SwiftUI has been known not to give the appearance back to iOS when the
  preference goes from Light or Dark to `nil`, which would have needed `overrideUserInterfaceStyle` on the scene's
  windows. Checked on the iOS 27.2 simulator: Dark to System with iOS on Light, and Light to System with iOS on Dark,
  each took effect at once, and with System chosen, `xcrun simctl ui <udid> appearance dark|light` switched the app
  both ways without a relaunch. So nothing sets `overrideUserInterfaceStyle`.

Rejected: an Appearance screen, for the reason above; storing it in the App Group or with the account, which the
extension doesn't need and signing out would clear.
