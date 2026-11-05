# Architecture

BufferSnap keeps its logic in **BufferSnapCore** (`Packages/BufferSnapCore`), a pure-Swift package with no UI
frameworks, so `just test-core` tests it on macOS in seconds without a simulator. The app and the widget are thin
SwiftUI shells over it.

- **Features** are `@Observable @MainActor` view models (`AppModel`, `CaptureModel`, `CaptureListModel`): they hold
  the state and the actions on it.
- **Services** are `Sendable` protocols with `async throws` methods (`CaptureStore`, `AuthService`, `BufferClient`,
  `ConnectivityMonitor`). Each one starts with a mock or in-memory implementation, and a real one replaces it later
  without touching the models. `JSONFileCaptureStore`, `OAuthAuthService`, `GraphQLBufferClient` and
  `NetworkPathConnectivityMonitor` are the real ones so far. `SubmissionQueue` is an actor on top of them.
- **`AppEnvironment`** bundles the services. `BufferSnapApp` builds it once, as the composition root, and is the
  only place that picks which implementations run.
- **Models** are plain `Sendable` values (`Capture`).
- **Views** (`App/Views/`) only render. `RootView` shows what `AppModel.route` names: sign-in, or the capture screen
  with the capture list pushed on top of it. A screen feeds a stateless view (`CaptureView`, `CaptureListView`) plain
  values and closures. `CaptureListScreen` owns its feature model, and `BufferSnapApp` owns `CaptureModel`, so a draft
  outlives the screen when a session ends. Conventions: [`App/CLAUDE.md`](../App/CLAUDE.md).
- **The widget** (`Widget/`) is a WidgetKit extension: an App Intent per button and a timeline that reads the count.
  Its buttons still make mock captures until #41 replaces them. Conventions: [`Widget/CLAUDE.md`](../Widget/CLAUDE.md).

Why: [`5-spm-core.md`](decisions/5-spm-core.md), [`5-core-ui-import-lint.md`](decisions/5-core-ui-import-lint.md).

## Layers

Arrows point from a layer to what it uses.

```mermaid
flowchart TD
    subgraph shells["UI shells (SwiftUI)"]
        App["App: BufferSnapApp → RootView<br/>(SignInView, CaptureScreen, CaptureListScreen)"]
        Widget["Widget: SnapperWidget, MockCaptureIntent"]
    end

    subgraph core["BufferSnapCore (no UI imports)"]
        Env["AppEnvironment"]
        subgraph features["Features"]
            AppModel["AppModel"]
            CaptureModel["CaptureModel"]
            CaptureListModel["CaptureListModel"]
        end
        subgraph services["Services (protocols)"]
            CaptureStore["CaptureStore"]
            AuthService["AuthService"]
            BufferClient["BufferClient"]
            Connectivity["ConnectivityMonitor"]
        end
        Queue["SubmissionQueue (planner, back-off)"]
        subgraph impls["Implementations"]
            InMemory["InMemoryCaptureStore"]
            MockAuth["MockAuthService"]
            FileStore["JSONFileCaptureStore"]
            Notifying["NotifyingCaptureStore (wraps a store)"]
            OAuth["OAuthAuthService → KeychainSessionStore"]
            GraphQL["GraphQLBufferClient, MockBufferClient"]
            Path["NetworkPathConnectivityMonitor, MockConnectivityMonitor"]
        end
        Capture["Models: Capture"]
    end

    App --> Env
    App --> features
    Widget --> FileStore
    Env --> services
    AppModel --> AuthService
    CaptureModel --> CaptureStore
    CaptureListModel --> CaptureStore
    CaptureListModel --> Queue
    Env --> Queue
    Queue --> CaptureStore
    Queue --> AuthService
    Queue --> BufferClient
    Queue --> Connectivity
    InMemory -->|implements| CaptureStore
    FileStore -->|implements| CaptureStore
    Notifying -->|implements| CaptureStore
    MockAuth -->|implements| AuthService
    OAuth -->|implements| AuthService
    GraphQL -->|implements| BufferClient
    Path -->|implements| Connectivity
    App -->|"SystemWebAuthenticator (needs a window)"| OAuth
    services --> Capture
```

## Data flow

```mermaid
flowchart LR
    Capture["App: CaptureScreen → CaptureModel"] -->|"add(_:)"| Notifying["App: NotifyingCaptureStore"]
    Delete["App: CaptureListView"] -->|"delete(id:)"| Notifying
    Notifying -->|"add(_:), delete(id:)"| Store[("captures-v2.json in the App Group<br/>(JSONFileCaptureStore)")]
    Notifying -.->|"reloads timelines"| Timeline["Widget: CaptureCountProvider"]
    Intent["Widget: MockCaptureIntent (until #41)"] -->|"add(_:)"| Store
    Store -->|"all()"| Timeline
    Timeline -->|"N captured"| Face["Widget: SnapperWidgetView"]
    Store -->|"all()"| List["CaptureListModel.load()"]
    List -->|captures| Delete
```

Typing an idea and tapping Save adds a pending text capture through `CaptureModel`. The write goes through
`NotifyingCaptureStore`, which reloads the widget's timelines afterwards, as a delete in the list does. When the list
opens, or the app returns to the foreground, it reads every capture from the store and shows them newest first.

## Signing in

```mermaid
sequenceDiagram
    participant Model as AppModel
    participant Auth as OAuthAuthService
    participant Web as SystemWebAuthenticator
    participant Page as site/oauth/
    participant Buffer as auth.buffer.com
    participant Keychain
    Model->>Auth: signIn()
    Auth->>Web: authenticate(url, "buffersnap")
    Web->>Buffer: Sign-in and consent, with state and the PKCE challenge
    Buffer->>Page: Redirect with code and state
    Page->>Web: Forward to buffersnap://oauth
    Web->>Auth: The callback URL
    Auth->>Buffer: POST /token with the code and PKCE verifier
    Buffer->>Auth: Access and refresh tokens
    Auth->>Keychain: Save, before anything uses them
    Auth->>Model: Done, route is now .capture
```

`AppModel` picks its first route from `hasSavedSession()`, which reads the Keychain, so the first frame is already right.
When the scene becomes active, `checkSession()` asks for a valid token, which refreshes it if it's due. Only Buffer
rejecting the refresh token sends the user back to sign-in. Everything that needs a token calls `validAccessToken()`,
and `OAuthAuthService` makes sure only one refresh ever runs, because reusing a refresh token revokes the session:
[`43-single-use-refresh-tokens.md`](decisions/43-single-use-refresh-tokens.md).

## Sending to Buffer

```mermaid
flowchart LR
    subgraph when["When: anything may call run()"]
        Launch["Launch, foreground"]
        Saved["CaptureModel saved"]
        Back["Connection returns"]
        Bg["Background refresh, leaving the screen"]
        Timer["Back-off or rate limit ends"]
    end
    subgraph queue["SubmissionQueue: one pass at a time"]
        Read["Read pending captures, oldest first"]
        Planner["What: SubmissionPlanner.nextSubmission"]
        Send["createIdea"]
        Read --> Planner --> Send
        Send -->|next| Read
    end
    when --> Read
    Send -->|"Submitted or Failed"| Store[("CaptureStore")]
    Send -.->|"capturesChanged"| List["CaptureListModel"]
    Send -.->|"sessionLost"| Check["AppModel.checkSession()"]
```

`SubmissionQueue` asks `validAccessToken()` for a token and reports a 401 with `accessTokenRejected(_:)`. Each pass looks up the organization once. A capture stays `pending` until Buffer has it (`submitted`) or it can't get there without someone stepping in (`failed`). What each failure leads to: [`44-what-gets-retried.md`](decisions/44-what-gets-retried.md). Why a lost response can leave a duplicate: [`44-duplicate-ideas.md`](decisions/44-duplicate-ideas.md).

All of this runs in the app's process, on the one `AuthService`: [`44-background-sending.md`](decisions/44-background-sending.md). Before any sign-in, pending captures turn to `failed`, so they can't reach the next account by themselves: [`44-hold-captures-at-sign-in.md`](decisions/44-hold-captures-at-sign-in.md).

To change what gets sent, as #45 will, implement `SubmissionPlanner`. Its result names the captures, and all of them change status together.

## The widget's store

The widget's mock buttons write to the same store until #41 replaces them, and WidgetKit then reloads the count. The
store contract is in [`Widget/CLAUDE.md`](../Widget/CLAUDE.md).

Installs from before #40 have a `captures.json` holding only mock captures. The app deletes it at launch and nothing
reads it: [`40-new-capture-file.md`](decisions/40-new-capture-file.md).
