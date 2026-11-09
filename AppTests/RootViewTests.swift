import BufferSnapCore
import SwiftUI
import Testing

@testable import BufferSnap

/// The whole app's root, rendered full-screen to AppTests/__Snapshots__/RootViewTests/.
@MainActor
struct RootViewTests {
    /// A fresh install lands on the list, in offline mode, without a sign-in screen in the way.
    @Test func firstLaunchShowsTheListInOfflineMode() async throws {
        let environment = Self.environment(auth: MockAuthService())
        let appModel = AppModel(auth: environment.auth)
        let captureModel = CaptureModel(store: environment.captureStore, speech: environment.speech)

        let root = RootView(appModel: appModel, captureModel: captureModel, environment: environment)
        assertScreenSnapshot(of: root, named: "firstLaunch")
    }

    /// Buffer ends the session mid-idea: the capture screen stays, with what they typed, with no takeover.
    @Test func draftAfterTheSessionEnded() async throws {
        let auth = MockAuthService(hasSavedSession: true)
        let environment = Self.environment(auth: auth)
        let appModel = AppModel(auth: auth)
        let captureModel = CaptureModel(store: environment.captureStore, speech: environment.speech)
        captureModel.update(text: "A half-typed idea")
        appModel.showCapture()

        await auth.signOut()
        await appModel.checkSession()
        #expect(appModel.route == .capture)
        #expect(!appModel.isSignedIn)

        let root = RootView(appModel: appModel, captureModel: captureModel, environment: environment)
        assertScreenSnapshot(of: root, named: "draftKept")
    }

    private static func environment(auth: any AuthService) -> AppEnvironment {
        AppEnvironment(
            captureStore: InMemoryCaptureStore(),
            auth: auth,
            speech: MockSpeechTranscriber(),
            bufferClient: MockBufferClient(),
            connectivity: MockConnectivityMonitor(),
            batchWindow: InMemoryBatchWindowSetting()
        )
    }
}
