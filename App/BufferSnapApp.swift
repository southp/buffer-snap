import BufferSnapCore
import OSLog
import SwiftUI

@main
struct BufferSnapApp: App {
    // Composition root: every service is built here, once, and handed down to the views.
    private let environment: AppEnvironment
    @State private var appModel: AppModel
    /// Dictation from the control and the widget, with the app closed. The intents run in this process and call it.
    private let handsFreeDictation: HandsFreeDictationSession
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let environment = AppEnvironment(
            captureStore: Self.makeCaptureStore(),
            auth: Self.makeAuthService(),
            bufferClient: Self.makeBufferClient(),
            connectivity: NetworkPathConnectivityMonitor(),
            batchWindow: UserDefaultsBatchWindowSetting()
        )
        self.environment = environment
        // Whoever signs in next may not be whoever made what's pending.
        let appModel = AppModel(
            auth: environment.auth,
            ideas: environment.submissions
        )
        _appModel = State(initialValue: appModel)
        handsFreeDictation = Self.makeHandsFreeDictation(
            store: environment.captureStore,
            submissions: environment.submissions,
            appModel: appModel
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel, environment: environment)
                .dictationNotice(appModel.dictationNotice, onDismiss: appModel.dismissDictationNotice)
                .task {
                    await removeMockCaptures()
                }
        }
        // Runs in this process and on this environment's queue, so there's still only one `AuthService`.
        .backgroundTask(.appRefresh(BackgroundSubmission.taskIdentifier)) { [environment] in
            BackgroundSubmission.scheduleWakeUp()
            await environment.submissions.run()
            await BackgroundSubmission.scheduleWakeUpForOpenBatch(on: environment.submissions)
        }
        // `initial`, as the scene is already active the first time this reads it: without it, a first launch won't ask.
        .onChange(of: scenePhase, initial: true) { _, phase in
            // A press can't ask for the mic with the app closed, so opening the app does. Then the first press works.
            if phase == .active && Self.asksForPermission {
                Task {
                    await handsFreeDictation.askForPermissionIfNeeded()
                }
            }
        }
    }

    /// The one session the intents reach, set before any of them can run: an intent's `perform()` is main-actor, so it
    /// waits for this `init`, even when the intent is what launched the app.
    private static func makeHandsFreeDictation(
        store: any CaptureStore,
        submissions: SubmissionQueue,
        appModel: AppModel
    ) -> HandsFreeDictationSession {
        let session = HandsFreeDictationSession(
            speech: AppleSpeechTranscriber(),
            store: store,
            display: LiveActivityDictationDisplay(),
            keepAlive: BackgroundTaskKeepAlive(),
            // Sends it if its batch is due, or asks iOS to wake the app when it will be, since the app may never come
            // to the foreground. The session keeps the process awake until this returns.
            onSaved: {
                await submissions.run()
                await BackgroundSubmission.scheduleWakeUpForOpenBatch(on: submissions)
            }
        )
        DictateIdeaIntent.onRun = {
            let result = await session.press()
            if case .needsTheApp(let reason) = result {
                appModel.showDictationNotice(for: reason)
            }
            return result
        }
        StopDictationIntent.onRun = {
            await session.stop()
        }
        return session
    }

    /// The system's prompts would wait forever in a test host and cover a screenshot, so those launch with
    /// `-skipPermissionPrompt YES`. Not in Release (`docs/decisions/77-ask-for-permissions-at-launch.md`).
    private static var asksForPermission: Bool {
        #if DEBUG
            return !UserDefaults.standard.bool(forKey: "skipPermissionPrompt")
        #else
            return true
        #endif
    }

    /// Mock captures from before the widget's buttons opened the capture screen must not reach Buffer.
    private func removeMockCaptures() async {
        do {
            try await environment.captureStore.removeMockCaptures()
        } catch {
            // The list can't read this file either, so this can wait for the next launch.
            Logger().error("Can't remove the mock captures: \(error)")
        }
    }

    /// Real Buffer OAuth, with the session in the Keychain. There must only ever be one of these: see `AuthService`.
    private static func makeAuthService() -> any AuthService {
        #if DEBUG
            // A way past sign-in on the simulator, not in Release (`docs/decisions/43-mock-auth-launch-argument.md`).
            if let mockAuth = UserDefaults.standard.string(forKey: "mockAuth") {
                return MockAuthService(hasSavedSession: mockAuth == "signedIn")
            }
        #endif
        return OAuthAuthService(
            web: SystemWebAuthenticator(),
            transport: URLSession.forOAuth(),
            store: KeychainSessionStore()
        )
    }

    /// Buffer's API. A mocked sign-in has no token to send, so it gets a mocked Buffer too, and nothing reaches the
    /// real one (`docs/decisions/44-mock-buffer-launch-argument.md`).
    private static func makeBufferClient() -> any BufferClient {
        #if DEBUG
            if UserDefaults.standard.string(forKey: "mockAuth") != nil {
                let failures: [BufferError] =
                    switch UserDefaults.standard.string(forKey: "mockBuffer") {
                    case "rejectFirst":
                        [.rejected(reason: "Mock")]
                    case "rateLimitFirst":
                        [.rateLimited(retryAfter: 120)]
                    default:
                        []
                    }
                return MockBufferClient(failures: failures)
            }
        #endif
        return GraphQLBufferClient(transport: URLSession.forBufferAPI())
    }

    /// The store in the App Group container, capped so it can't grow forever.
    private static func makeCaptureStore() -> any CaptureStore {
        do {
            try SharedStorage.removeLegacyCaptures()
        } catch {
            // It's only mock captures that nothing reads any more, so this can wait for the next launch.
            Logger().error("Can't remove the old capture file: \(error)")
        }
        let store: any CaptureStore
        do {
            store = JSONFileCaptureStore(fileURL: try SharedStorage.capturesFileURL())
        } catch {
            // Still usable, but nothing persists. Only a build without the App Group entitlement gets here,
            // so it's logged, not shown: `docs/decisions/46-in-memory-fallback-stays-silent.md`.
            Logger().error("Can't open the shared capture store: \(error)")
            store = InMemoryCaptureStore()
        }
        return CappedCaptureStore(base: store)
    }
}
