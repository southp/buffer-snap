import BufferSnapCore
import SwiftUI
import Testing

@testable import BufferSnap

/// The whole app's root, rendered full-screen to AppTests/__Snapshots__/RootViewTests/.
@MainActor
struct RootViewTests {
    /// Buffer ends the session mid-idea and the user signs back in: the capture screen still has what they typed.
    @Test func draftAfterTheSessionEnded() async throws {
        let auth = MockAuthService(hasSavedSession: true)
        let environment = AppEnvironment(
            captureStore: InMemoryCaptureStore(),
            auth: auth,
            bufferClient: MockBufferClient(),
            connectivity: MockConnectivityMonitor()
        )
        let appModel = AppModel(auth: auth)
        let captureModel = CaptureModel(store: environment.captureStore)
        captureModel.update(text: "A half-typed idea")

        await auth.signOut()
        await appModel.checkSession()
        #expect(appModel.route == .signedOut)
        await appModel.signIn()
        #expect(appModel.route == .capture)

        let root = RootView(appModel: appModel, captureModel: captureModel, environment: environment)
        assertScreenSnapshot(of: root, named: "draftKept")
    }
}
