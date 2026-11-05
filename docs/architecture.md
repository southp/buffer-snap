# Architecture

BufferSnap keeps its logic in **BufferSnapCore** (`Packages/BufferSnapCore`), a pure-Swift package with no UI
frameworks, so `just test-core` tests it on macOS in seconds without a simulator. The app and the widget are thin
SwiftUI shells over it.

- **Features** are `@Observable @MainActor` view models (`AppModel`, `CaptureModel`, `CaptureListModel`,
  `BatchingSettingsModel`): they hold the state and the actions on it.
- **Services** are `Sendable` protocols with `async throws` methods (`CaptureStore`, `AuthService`,
  `SpeechTranscriber`, `BufferClient`, `ConnectivityMonitor`, `BatchWindowSetting`). Each one starts with a mock or
  in-memory implementation, and a real one replaces it later without touching the models. `JSONFileCaptureStore`,
  `OAuthAuthService`, `GraphQLBufferClient` and `NetworkPathConnectivityMonitor` are the real ones so far.
  `SubmissionQueue` is an actor on top of them. `AppleSpeechTranscriber` lives in the app rather than Core, because
  `AVAudioSession` doesn't exist on macOS, where Core's tests run.
- **`AppEnvironment`** bundles the services. `BufferSnapApp` builds it once, as the composition root, and is the
  only place that picks which implementations run.
- **Models** are plain `Sendable` values (`Capture`).
- **Views** (`App/Views/`) only render. `RootView` shows what `AppModel.route` names: sign-in, or the capture screen
  with the capture list pushed on top of it. A screen feeds a stateless view (`CaptureView`, `CaptureListView`) plain
  values and closures. `CaptureListScreen` owns its feature model, and `BufferSnapApp` owns `CaptureModel`, so a draft
  outlives the screen when a session ends. Conventions: [`App/CLAUDE.md`](../App/CLAUDE.md).
- **The widget** (`Widget/`) is a WidgetKit extension: a control, a widget for the Home Screen, Today View and Lock
  Screen, and a timeline that reads the count. The control and the Home Screen widget run `OpenCaptureIntent` (`Shared/`,
  compiled into both the app and the widget), and the Lock Screen widget opens `buffersnap://capture`. Both open the
  app on the capture screen. Conventions:
  [`Widget/CLAUDE.md`](../Widget/CLAUDE.md).

Why: [`5-spm-core.md`](decisions/5-spm-core.md), [`5-core-ui-import-lint.md`](decisions/5-core-ui-import-lint.md).

## Layers

Arrows point from a layer to what it uses.

```mermaid
flowchart TD
    subgraph shells["UI shells (SwiftUI)"]
        App["App: BufferSnapApp → RootView<br/>(SignInView, CaptureScreen, CaptureListScreen, BatchingSettingsScreen)"]
        Widget["Widget: SnapperWidget, OpenCaptureControl"]
        Intent["Shared: OpenCaptureIntent"]
        AppleSpeech["App: AppleSpeechTranscriber"]
    end

    subgraph core["BufferSnapCore (no UI imports)"]
        Env["AppEnvironment"]
        subgraph features["Features"]
            AppModel["AppModel"]
            CaptureModel["CaptureModel"]
            CaptureListModel["CaptureListModel"]
            BatchingSettings["BatchingSettingsModel"]
        end
        subgraph services["Services (protocols)"]
            CaptureStore["CaptureStore"]
            AuthService["AuthService"]
            SpeechTranscriber["SpeechTranscriber"]
            BufferClient["BufferClient"]
            Connectivity["ConnectivityMonitor"]
            Window["BatchWindowSetting"]
        end
        Queue["SubmissionQueue (planner, back-off)"]
        subgraph impls["Implementations"]
            InMemory["InMemoryCaptureStore"]
            MockAuth["MockAuthService"]
            MockSpeech["MockSpeechTranscriber"]
            FileStore["JSONFileCaptureStore"]
            Notifying["NotifyingCaptureStore (wraps a store)"]
            OAuth["OAuthAuthService → KeychainSessionStore"]
            GraphQL["GraphQLBufferClient, MockBufferClient"]
            Path["NetworkPathConnectivityMonitor, MockConnectivityMonitor"]
            Defaults["UserDefaultsBatchWindowSetting, InMemoryBatchWindowSetting"]
        end
        Capture["Models: Capture"]
    end

    App --> Env
    App --> features
    App --> Intent
    Widget --> Intent
    Widget --> FileStore
    Env --> services
    AppModel --> AuthService
    CaptureModel --> CaptureStore
    CaptureModel --> SpeechTranscriber
    CaptureListModel --> CaptureStore
    CaptureListModel --> Queue
    BatchingSettings --> Window
    BatchingSettings --> Queue
    Env --> Queue
    Queue --> CaptureStore
    Queue --> AuthService
    Queue --> BufferClient
    Queue --> Connectivity
    Queue --> Window
    InMemory -->|implements| CaptureStore
    FileStore -->|implements| CaptureStore
    Notifying -->|implements| CaptureStore
    MockAuth -->|implements| AuthService
    OAuth -->|implements| AuthService
    GraphQL -->|implements| BufferClient
    Path -->|implements| Connectivity
    Defaults -->|implements| Window
    App -->|"SystemWebAuthenticator (needs a window)"| OAuth
    MockSpeech -->|implements| SpeechTranscriber
    AppleSpeech -->|implements| SpeechTranscriber
    services --> Capture
```

## Data flow

```mermaid
flowchart LR
    Mic["App: AppleSpeechTranscriber"] -->|"words heard so far"| Capture
    Capture["App: CaptureScreen → CaptureModel"] -->|"add(_:)"| Notifying["App: NotifyingCaptureStore"]
    Delete["App: CaptureListView"] -->|"delete(id:)"| Notifying
    Notifying -->|"add(_:), delete(id:)"| Store[("captures-v2.json in the App Group<br/>(JSONFileCaptureStore)")]
    Notifying -.->|"reloads timelines"| Timeline["Widget: CaptureCountProvider"]
    Store -->|"all()"| Timeline
    Timeline -->|"N captured"| Face["Widget: SnapperWidgetView"]
    Store -->|"all()"| List["CaptureListModel.load()"]
    List -->|captures| Delete
```

Holding the mic shows the words in the text box as they're heard, and releasing saves them through `CaptureModel`.
Nothing is saved if nothing was heard, and words that can't save on release stay in the box to edit
([`42-over-limit-dictation.md`](decisions/42-over-limit-dictation.md)). No audio is kept.

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
        Timer["Back-off or rate limit ends, or a batch's window"]
    end
    subgraph queue["SubmissionQueue: one pass at a time"]
        Read["Read pending captures"]
        Planner["What: SubmissionPlanner.plan"]
        Close["Close the batch: store its batchID"]
        Send["createIdea, one per batch"]
        Read --> Planner -->|"send"| Close --> Send
        Send -->|next| Read
    end
    when --> Read
    Send -->|"Submitted or Failed"| Store[("CaptureStore")]
    Send -.->|"capturesChanged"| List["CaptureListModel"]
    Send -.->|"sessionLost"| Check["AppModel.checkSession()"]
    Planner -.->|"wait until"| Timer
```

`SubmissionQueue` asks `validAccessToken()` for a token and reports a 401 with `accessTokenRejected(_:)`. Each pass looks up the organization once. A capture stays `pending` until Buffer has it (`submitted`) or it can't get there without someone stepping in (`failed`). What each failure leads to: [`44-what-gets-retried.md`](decisions/44-what-gets-retried.md). Why a lost response can leave a duplicate: [`44-duplicate-ideas.md`](decisions/44-duplicate-ideas.md).

All of this runs in the app's process, on the one `AuthService`: [`44-background-sending.md`](decisions/44-background-sending.md). Before any sign-in, pending captures turn to `failed`, so they can't reach the next account by themselves: [`44-hold-captures-at-sign-in.md`](decisions/44-hold-captures-at-sign-in.md).

## Batches

Captures with less than the window between them (5 minutes unless the setting says otherwise) become one idea, in the order they were made, separated by blank lines.

```mermaid
stateDiagram-v2
    [*] --> Open: Saved
    Open --> Open: Another capture restarts the window
    Open --> Closed: The window has ended, or Send now
    Open --> Failed: Held before a sign-in
    Closed --> Submitted: createIdea succeeds
    Closed --> Closed: No answer, so the same text goes again
    Closed --> Failed: Refused, too many server failures, or held
    Failed --> Closed: Resend
```

`CaptureBatch.batches` is the one place that groups, and it's pure. An open batch comes from timestamps and the current window, so a relaunch mid-window needs nothing restored, and a wake-up follows from what the planner says. A closed batch comes from its captures' `batchID`, written just before the first attempt, so a retry sends the same text and a capture saved after that goes in the next batch: [`45-batch-membership.md`](decisions/45-batch-membership.md).

- Changing the setting applies at once to whatever is open: [`45-changing-the-window.md`](decisions/45-changing-the-window.md). On a simulator, the launch argument `-batchWindow 20` makes the window 20 seconds, which saves waiting while trying it out.
- Resend works on a batch, and delete on a capture: [`45-resend-and-delete.md`](decisions/45-resend-and-delete.md).
- A joined batch has no length limit of its own: [`45-joined-batch-length.md`](decisions/45-joined-batch-length.md).
- The wake-up iOS is asked for: [`45-background-wake-at-window-end.md`](decisions/45-background-wake-at-window-end.md).

## The widget's store

The widget only reads the store. The store contract is in [`Widget/CLAUDE.md`](../Widget/CLAUDE.md).

Installs from before #40 have a `captures.json` holding only mock captures. The app deletes it at launch and nothing
reads it: [`40-new-capture-file.md`](decisions/40-new-capture-file.md). Installs from between #40 and #41 can have mock
captures among real ones in `captures-v2.json`, and the app deletes just those at launch:
[`41-remove-mock-captures-by-text.md`](decisions/41-remove-mock-captures-by-text.md).

## Opening the capture screen

```mermaid
flowchart LR
    Surface["Control or Home Screen widget"] -->|runs| Intent["OpenCaptureIntent (openAppWhenRun)"]
    Intent -->|"the system opens the app, then runs perform() in it"| Hook["OpenCaptureIntent.onRun"]
    Hook --> Show["AppModel.showCapture()"]
    Lock["Lock Screen widget"] -->|"widgetURL"| URL["buffersnap://capture"]
    URL -->|"onOpenURL, if AppLink(url:) is .capture"| Show
    Show -->|"on the capture list"| Capture["Capture screen"]
    Show -.->|"anywhere else: nothing to do"| Route["Route stays, and every way past sign-in ends on capture"]
```

From a locked phone, the system asks to unlock first, since the intent isn't always allowed, and a widget tap always
needs an unlock to open the app. The Lock Screen widget uses a URL because its intent button didn't run on a device:
[`41-lock-screen-widget-url.md`](decisions/41-lock-screen-widget-url.md). A cold launch reaches
capture whichever comes first, the intent or getting past sign-in:
[`41-no-remembered-capture-request.md`](decisions/41-no-remembered-capture-request.md).
