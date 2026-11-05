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
        let environment = AppEnvironment(
            captureStore: Self.makeCaptureStore(),
            auth: MockAuthService(),
            speech: AppleSpeechTranscriber()
        )
        self.environment = environment
        _appModel = State(initialValue: AppModel(auth: environment.auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel, environment: environment)
        }
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
