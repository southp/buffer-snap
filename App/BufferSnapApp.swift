import BufferSnapCore
import OSLog
import SwiftUI

@main
struct BufferSnapApp: App {
    // Composition root: every service is built here, once, and handed down to the views.
    private let environment: AppEnvironment
    @State private var appModel: AppModel

    init() {
        let environment = AppEnvironment(captureStore: Self.makeCaptureStore(), auth: MockAuthService())
        self.environment = environment
        _appModel = State(initialValue: AppModel(auth: environment.auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel, environment: environment)
        }
    }

    /// The App Group store the widget also writes to, seeded with the mock captures on the first launch.
    private static func makeCaptureStore() -> any CaptureStore {
        let seed = Capture.samples(relativeTo: .now)
        do {
            return try JSONFileCaptureStore(fileURL: SharedStorage.capturesFileURL(), seedIfMissing: seed)
        } catch {
            // Still usable, but nothing persists or reaches the widget. Showing this comes with the MVP.
            Logger().error("Can't open the shared capture store: \(error)")
            return InMemoryCaptureStore(seed: seed)
        }
    }
}
