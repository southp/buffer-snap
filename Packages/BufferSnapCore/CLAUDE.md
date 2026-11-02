# BufferSnapCore

The app's logic: models, services and view models. Layers and data flow: [`docs/architecture.md`](../../docs/architecture.md).

## Rules

- **Logic lives here, so views stay thin.** State, actions, routing and persistence go in Core, where
  `just test-core` covers them. A SwiftUI view only renders a model and forwards taps to its actions.
- **No UI imports.** Never import SwiftUI, SwiftUICore, UIKit, AppKit or WidgetKit here, tests included.
  `just lint` fails on it (`no_ui_import_in_core` in `.swiftlint.yml`); don't work around it.
- **A new service starts as a protocol plus a mock.** Make the protocol `Sendable` with `async throws` methods,
  ship an in-memory or mock implementation next to it (an `actor` if it holds state), and add it to
  `AppEnvironment`. The real implementation comes later and only `BufferSnapApp` picks it.
- **View models are `@Observable @MainActor final class`es** under `Features/`. They take services through `init`
  and never build them. Expose state as `public private(set) var`; change it only through actions.

## Layout

| Folder | Holds |
|---|---|
| `Sources/BufferSnapCore/Models/` | Plain `Sendable` value types (`Capture`) |
| `Sources/BufferSnapCore/Services/` | Service protocols, their mocks, and `AppEnvironment` |
| `Sources/BufferSnapCore/Features/` | View models (`AppModel`, `CaptureListModel`) |
| `Tests/BufferSnapCoreTests/` | Swift Testing tests; test-only fakes go in `TestDoubles.swift` |

## Testing

- `just test-core` runs `swift test` on macOS: no simulator, no Xcode project. `just test` runs it too.
- Test public behavior through `import BufferSnapCore` (not `@testable`), and test models against
  `InMemoryCaptureStore` / `MockAuthService`, or a failing fake from `TestDoubles.swift` for error paths.
- Mark suites that use view models `@MainActor`.
