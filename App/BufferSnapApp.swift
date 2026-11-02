import BufferSnapCore
import SwiftUI

@main
struct BufferSnapApp: App {
    // Composition root: every service is built here, once, and handed down to the views.
    private let environment: AppEnvironment
    @State private var appModel: AppModel

    init() {
        let environment = AppEnvironment.mock(seed: Capture.samples(relativeTo: .now))
        self.environment = environment
        _appModel = State(initialValue: AppModel(auth: environment.auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel, environment: environment)
        }
    }
}
