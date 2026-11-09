---
date: 2026-11-06
issue: 41
status: superseded
superseded_by: 77-lock-screen-widget-dictates.md
---

# Open the capture screen from the Lock Screen widget with a URL

**Decision:** The Lock Screen widget (`accessoryCircular`) opens `buffersnap://capture` through `widgetURL`. The app registers the `buffersnap` scheme and handles that one host in `onOpenURL`. The Home Screen widget and the control keep `OpenCaptureIntent`, which worked on the device.

**Why:** On an iPhone 16 Pro with iOS 26.7.1, unlocked, tapping the round widget's `Button(intent: OpenCaptureIntent())` opened the app on the screen it was left on: the intent never ran. Apple lists `accessoryCircular` among the families that can hold buttons, but also says that an interaction that only opens the app should use `Link` and `widgetURL` instead ("Adding interactivity to widgets and Live Activities"). Apple's linking guide routes taps to `widgetURL` in families with one tap target, which `accessoryCircular` is, and hands the URL to `onOpenURL`.

The scheme is the one sign-in already returns through as `buffersnap://oauth`. `ASWebAuthenticationSession` catches its callback inside its own browser, so registering the scheme doesn't change sign-in. If that URL ever reaches the app another way, `AppLink` ignores it.

Rejected:

- **No URL, reading the `NSUserActivity` a plain widget tap sends:** Apple documents the user info keys but not the activity's type, which `onContinueUserActivity` needs.
- **A scheme of its own, such as `buffersnap-capture`:** it would leave sign-in's scheme unregistered, but it's a second name for the same app.
- **A Universal Link:** Associated Domains, and `southp.github.io/buffer-snap` isn't a domain root (`43-oauth-redirect-page.md`).
