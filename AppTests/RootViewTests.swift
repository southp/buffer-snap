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

        let root = RootView(appModel: appModel, environment: environment)
        assertScreenSnapshot(of: root, named: "firstLaunch")
    }

    private static func environment(auth: any AuthService) -> AppEnvironment {
        AppEnvironment(
            captureStore: InMemoryCaptureStore(),
            auth: auth,
            bufferClient: MockBufferClient(),
            connectivity: MockConnectivityMonitor(),
            batchWindow: InMemoryBatchWindowSetting()
        )
    }
}
