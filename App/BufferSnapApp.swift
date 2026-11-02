import BufferSnapCore
import SwiftUI

@main
struct BufferSnapApp: App {
    // Composition root: every service is built here, once. Views receive it once they exist (#3).
    private let environment = AppEnvironment.mock(seed: Capture.samples)

    var body: some Scene {
        WindowGroup {
            Text("BufferSnap")
        }
    }
}
