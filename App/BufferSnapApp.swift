import BufferSnapCore
import OSLog
import SwiftUI
import WidgetKit

@main
struct BufferSnapApp: App {
    // Composition root: every service is built here, once, and handed down to the views.
    private let environment: AppEnvironment
    @State private var appModel: AppModel
    // Throwaway spike: T4's notification reply.
    @UIApplicationDelegateAdaptor(SpikeAppDelegate.self) private var spikeAppDelegate

    init() {
        let environment = AppEnvironment(
            captureStore: Self.makeCaptureStore(),
            auth: Self.makeAuthService(),
            speech: AppleSpeechTranscriber()
        )
        self.environment = environment
        let appModel = AppModel(auth: environment.auth)
        _appModel = State(initialValue: appModel)
        OpenCaptureIntent.onRun = { appModel.showCapture() }
        SpikeDictation.install()
    }

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel, environment: environment)
                .task {
                    await removeMockCaptures()
                }
                .task {
                    // Throwaway spike: what T1 and T4 can't ask for from the background.
                    await SpikeDictation.shared.requestPermission()
                    await SpikeAppDelegate.requestNotificationPermission()
                }
                // The Lock Screen widget opens `buffersnap://capture`. Other URLs, such as sign-in's, aren't ours.
                .onOpenURL { url in
                    if AppLink(url: url) == .capture {
                        appModel.showCapture()
                    }
                }
        }
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

    /// The App Group store the widget also writes to. Every write through it reloads the widget, so its count never
    /// goes stale.
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
            // Still usable, but nothing persists or reaches the widget. Showing this comes with the MVP.
            Logger().error("Can't open the shared capture store: \(error)")
            store = InMemoryCaptureStore()
        }
        let reloadWidget: @Sendable () -> Void = {
            WidgetCenter.shared.reloadTimelines(ofKind: SharedStorage.widgetKind)
        }
        // A widget added before an update may still show the count of the mock captures that update removed.
        reloadWidget()
        return NotifyingCaptureStore(base: store, onChange: reloadWidget)
    }
}
