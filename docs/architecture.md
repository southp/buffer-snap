# Architecture

BufferSnap keeps its logic in **BufferSnapCore** (`Packages/BufferSnapCore`), a pure-Swift package with no UI
frameworks, so `just test-core` tests it on macOS in seconds without a simulator. The app and the widget are thin
SwiftUI shells over it.

- **Features** are `@Observable @MainActor` view models (`AppModel`, `CaptureListModel`): they hold the state and the
  actions on it.
- **Services** are `Sendable` protocols with `async throws` methods (`CaptureStore`, `AuthService`). Each one starts
  with a mock or in-memory implementation, and a real one replaces it later without touching the models.
  `JSONFileCaptureStore` is the first real one.
- **`AppEnvironment`** bundles the services. `BufferSnapApp` builds it once, as the composition root, and is the
  only place that picks which implementations run.
- **Models** are plain `Sendable` values (`Capture`).
- **Views** (`App/Views/`) only render. `RootView` switches on `AppModel.route`; a screen (`CaptureListScreen`) owns
  its feature model and feeds a stateless view (`CaptureListView`) plain values and closures. Conventions:
  [`App/CLAUDE.md`](../App/CLAUDE.md).
- **The widget** (`Widget/`) is a WidgetKit extension: an App Intent per button and a timeline that reads the count.
  Conventions: [`Widget/CLAUDE.md`](../Widget/CLAUDE.md).

Why: [`5-spm-core.md`](decisions/5-spm-core.md), [`5-core-ui-import-lint.md`](decisions/5-core-ui-import-lint.md).

## Layers

Arrows point from a layer to what it uses. Dashed boxes and arrows don't exist yet.

```mermaid
flowchart TD
    subgraph shells["UI shells (SwiftUI)"]
        App["App: BufferSnapApp → RootView<br/>(SignInView, CaptureListScreen)"]
        Widget["Widget: SnapperWidget, MockCaptureIntent"]
    end

    subgraph core["BufferSnapCore (no UI imports)"]
        Env["AppEnvironment"]
        subgraph features["Features"]
            AppModel["AppModel"]
            CaptureListModel["CaptureListModel"]
        end
        subgraph services["Services (protocols)"]
            CaptureStore["CaptureStore"]
            AuthService["AuthService"]
        end
        subgraph impls["Implementations"]
            InMemory["InMemoryCaptureStore"]
            MockAuth["MockAuthService"]
            FileStore["JSONFileCaptureStore"]
            Notifying["NotifyingCaptureStore (wraps a store)"]
            OAuth["Buffer OAuth (MVP)"]
        end
        Capture["Models: Capture"]
    end

    App --> Env
    App --> features
    Widget --> FileStore
    Env --> services
    AppModel --> AuthService
    CaptureListModel --> CaptureStore
    InMemory -->|implements| CaptureStore
    FileStore -->|implements| CaptureStore
    Notifying -->|implements| CaptureStore
    MockAuth -->|implements| AuthService
    OAuth -.->|implements| AuthService
    services --> Capture

    classDef planned stroke-dasharray: 5 5
    class OAuth planned
```

## Data flow

```mermaid
flowchart LR
    Intent["Widget: MockCaptureIntent"] -->|"add(_:)"| Store[("captures.json in the App Group<br/>(JSONFileCaptureStore)")]
    Store -->|"all()"| Timeline["Widget: CaptureCountProvider"]
    Timeline -->|"N captured"| Face["Widget: SnapperWidgetView"]
    Store -->|"all()"| List["CaptureListModel.load()"]
    List -->|captures| View["App: CaptureListScreen → CaptureListView"]
    View -->|"delete(id:)"| Notifying["App: NotifyingCaptureStore"]
    Notifying -->|"delete(id:)"| Store
    Notifying -.->|"reloads timelines"| Timeline
```

A capture made in the widget is written to the shared App Group store, and WidgetKit then reloads the widget's count.
When the app's list loads, or the app returns to the foreground, it reads every capture from that store and shows them
newest first. A delete in the app goes through `NotifyingCaptureStore`, which reloads the widget's timelines after the
write. The store contract is in [`Widget/CLAUDE.md`](../Widget/CLAUDE.md).
