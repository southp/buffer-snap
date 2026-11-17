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
    /// The account menu's appearance choice, kept on this iPhone (`docs/decisions/144-appearance-setting.md`).
    @AppStorage(Appearance.storageKey) private var storedAppearance: String?

    init() {
        let environment = AppEnvironment(
            captureStore: Self.makeCaptureStore(),
            auth: Self.makeAuthService(),
            bufferClient: Self.makeBufferClient(),
            connectivity: NetworkPathConnectivityMonitor(),
            batchWindow: UserDefaultsBatchWindowSetting(),
            accountStore: Self.makeAccountStore(),
            avatarDownloader: Self.makeAvatarDownloader(),
            avatarStore: Self.makeAvatarStore()
        )
        self.environment = environment
        // One for the app's model, which only reads its permission, and for the session, which listens.
        let speech = AppleSpeechTranscriber()
        // Whoever signs in next may not be whoever made what's pending.
        let appModel = AppModel(
            auth: environment.auth,
            ideas: environment.submissions,
            speech: speech,
            accounts: environment.submissions,
            accountStore: environment.accountStore,
            avatars: environment.avatarDownloader,
            avatarStore: environment.avatarStore
        )
        _appModel = State(initialValue: appModel)
        handsFreeDictation = Self.makeHandsFreeDictation(
            speech: speech,
            store: environment.captureStore,
            submissions: environment.submissions,
            appModel: appModel
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel, environment: environment)
                .dictationNotice(appModel.dictationNotice, onDismiss: appModel.dismissDictationNotice)
                // On the window's content, so the sheets and alerts it presents follow it too. Not on `RootView`,
                // whose snapshot test sets its own appearance.
                .preferredColorScheme(Appearance(storedValue: storedAppearance).colorScheme)
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
            guard phase == .active else {
                return
            }
            Task {
                // A press can't ask for the mic with the app closed, so opening the app does. Then the first press
                // works.
                if Self.asksForPermission {
                    await handsFreeDictation.askForPermissionIfNeeded()
                }
                // It may have changed in Settings while the app was away, or just now, in the prompts.
                await appModel.refreshSpeechPermission()
            }
        }
    }

    /// The one session the intents reach, set before any of them can run: an intent's `perform()` is main-actor, so it
    /// waits for this `init`, even when the intent is what launched the app.
    private static func makeHandsFreeDictation(
        speech: any SpeechTranscriber,
        store: any CaptureStore,
        submissions: SubmissionQueue,
        appModel: AppModel
    ) -> HandsFreeDictationSession {
        let session = HandsFreeDictationSession(
            speech: speech,
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

    /// The signed-in account's name and email, in their own Keychain item (`docs/decisions/92-account-cache.md`). A
    /// mocked sign-in gets a made-up account, already saved when it starts signed in, so screenshots show it at once.
    private static func makeAccountStore() -> any AccountStore {
        #if DEBUG
            if let mockAuth = UserDefaults.standard.string(forKey: "mockAuth") {
                let saved = SavedAccount(account: .mock, fetchedAt: Date())
                return InMemoryAccountStore(account: mockAuth == "signedIn" ? saved : nil)
            }
        #endif
        return KeychainAccountStore()
    }

    /// The account's picture, from Buffer's bucket on S3 and nowhere else. A mocked sign-in gets a made-up picture
    /// drawn on the iPhone, so nothing reaches the network (`docs/decisions/108-avatar-from-buffers-s3.md`).
    private static func makeAvatarDownloader() -> any AvatarDownloader {
        #if DEBUG
            if UserDefaults.standard.string(forKey: "mockAuth") != nil {
                return MockAvatarDownloader(picture: MockAvatarPicture.png)
            }
        #endif
        return HTTPAvatarDownloader(transport: URLSession.forAvatars())
    }

    /// The account's picture between launches, in the app's own Application Support. A mocked sign-in that starts
    /// signed in has its made-up picture already saved, so screenshots show it at once.
    private static func makeAvatarStore() -> any AvatarImageStore {
        #if DEBUG
            if let mockAuth = UserDefaults.standard.string(forKey: "mockAuth") {
                guard mockAuth == "signedIn", let url = BufferAccount.mock.avatarURL else {
                    return InMemoryAvatarImageStore()
                }
                return InMemoryAvatarImageStore(image: MockAvatarPicture.png, from: url)
            }
        #endif
        return FileAvatarImageStore()
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
