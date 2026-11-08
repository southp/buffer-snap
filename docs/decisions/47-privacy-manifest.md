---
date: 2026-11-08
issue: 47
status: accepted
---

# Declare UserDefaults in both bundles, and the captures' text as collected

**Decision:** The app and the widget extension each ship a `PrivacyInfo.xcprivacy`.

| Entry | App | Widget |
|---|---|---|
| `NSPrivacyTracking` | `false`, no tracking domains | `false`, no tracking domains |
| Required-reason APIs | `UserDefaults`, reason `CA92.1` | `UserDefaults`, reason `CA92.1` |
| Collected data | Other User Content: linked to the user, not tracking, App Functionality | None |

Each manifest sits in its target's folder, so XcodeGen copies it as a resource without a `target.yml` entry of its own.

**Why the required-reason APIs:** Apple checks each binary for the APIs it links, so the list comes from the Release
binaries, not only from reading the code:

```sh
nm -u <BufferSnap.app>/BufferSnap
nm -u <BufferSnap.app>/PlugIns/BufferSnapWidget.appex/BufferSnapWidget
```

- **`UserDefaults`** (`_OBJC_CLASS_$_NSUserDefaults`) is in both. The app reads and writes the batching setting
  (`UserDefaultsBatchWindowSetting`) and, in Debug, reads launch arguments. The widget never calls it, but it links
  BufferSnapCore, and the setting's code stays in its binary. Both read only their own defaults, never an App Group's,
  which is what `CA92.1` covers. `1C8F.1` (App Group defaults) would be wrong: captures are shared through a file.
- **Nothing else is linked.** No `systemUptime`, `mach_absolute_time` or `CACurrentMediaTime` (boot time); no `stat`,
  `getattrlist` or creation and modification date keys (file timestamps); no capacity keys or `statfs` (disk space); no
  `activeInputModes` (keyboards). The store reads and writes `captures-v2.json` whole and only asks whether the legacy
  file exists, which isn't a timestamp API.
- **`ContinuousClock` isn't declared.** The Live Activity uses it to space out updates. It isn't on Apple's list, and it
  links none of the listed symbols. If Apple's list grows to include it, the reason is `35F9.1`: time between events in
  the app.

Rerun the `nm` check, on a Release build, whenever a new framework or dependency comes in.

**Why the collected data:** Apple counts data as collected when it leaves the device and the developer or a partner can
keep it. BufferSnap has no server, and only Buffer, which the user signs in to, receives the text of their captures.
That makes "Data Not Collected" arguable, but Buffer is an outside service the app was built to send to, so the
manifest and the App Privacy answers declare that text as Other User Content, linked to the user's Buffer account, for
App Functionality only. Declaring more than needed is safe, and declaring less is what gets an app rejected.

Not declared:

- **Audio.** It goes to Apple's speech recognition, which Apple's own privacy covers, and the app keeps none of it.
- **Sign-in tokens and the organization ID.** They're Buffer's credentials and Buffer's identifier, sent back to
  Buffer, not data about the user that the app collects.
- **Crash data or diagnostics.** The app sends none: iOS's own reports go to Apple.

Rejected:

- **No manifest in the widget:** Apple's upload check names each binary, extensions included, that links a
  required-reason API without a manifest.
- **Declaring every required-reason category "just in case":** a declaration states what the app does, so it should
  match the binary.
