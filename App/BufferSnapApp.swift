import BufferSnapCore
import OSLog
import SwiftUI
import WidgetKit

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
            TabView {
                SpikeView()
                    .tabItem {
                        Label("Spike", systemImage: "lock")
                    }
                RootView(appModel: appModel, environment: environment)
                    .tabItem {
                        Label("App", systemImage: "tray")
                    }
            }
        }
    }

    /// The App Group store the widget also writes to, seeded with the mock captures on the first launch. Every write
    /// through it reloads the widget, so its count never goes stale.
    private static func makeCaptureStore() -> any CaptureStore {
        let seed = Capture.samples(relativeTo: .now)
        let store: any CaptureStore
        do {
            store = try JSONFileCaptureStore(fileURL: SharedStorage.capturesFileURL(), seedIfMissing: seed)
        } catch {
            // Still usable, but nothing persists or reaches the widget. Showing this comes with the MVP.
            Logger().error("Can't open the shared capture store: \(error)")
            store = InMemoryCaptureStore(seed: seed)
        }
        let reloadWidget: @Sendable () -> Void = {
            WidgetCenter.shared.reloadTimelines(ofKind: SharedStorage.widgetKind)
        }
        // The seed above may have just changed the count of a widget added before this first launch.
        reloadWidget()
        return NotifyingCaptureStore(base: store, onChange: reloadWidget)
    }
}
