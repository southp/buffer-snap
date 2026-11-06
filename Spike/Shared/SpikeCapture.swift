import BufferSnapCore
import Foundation
import OSLog
import WidgetKit

// Throwaway spike: can an idea be captured on an unlocked iPhone without the app opening? Never merge.
// Compiled into both the app and the widget, so an intent here runs wherever the system decides.

/// Saves each experiment's outcome as a capture, so the result shows in the capture list without a Mac.
enum SpikeCapture {
    /// The process this code runs in: "BufferSnap" for the app, "BufferSnapWidget" for the extension.
    static var processName: String {
        ProcessInfo.processInfo.processName
    }

    /// Saves `[test] outcome (in <process>)` straight to the App Group file, the same way the app's store does.
    static func save(_ test: String, _ outcome: String) async {
        let text = "[\(test)] \(outcome) (in \(processName))"
        do {
            let store = JSONFileCaptureStore(fileURL: try SharedStorage.capturesFileURL())
            try await store.add(Capture(kind: .text, text: text))
        } catch {
            // Never the text: only that the write failed.
            Logger().error("Spike \(test, privacy: .public): can't save the outcome: \(error)")
        }
        WidgetCenter.shared.reloadTimelines(ofKind: SharedStorage.widgetKind)
    }
}

/// What only the app can do. The app sets these at launch; in the widget's process they stay `nil`, so an intent that
/// finds them `nil` knows it ran in the widget.
@MainActor
enum SpikeHooks {
    /// Starts T1's dictation, or stops it if it's running. `source` says which surface was pressed.
    static var toggleDictation: (@MainActor (_ source: String) async -> Void)?
    /// Ends T1's dictation, from the Live Activity's Stop button.
    static var stopDictation: (@MainActor () async -> Void)?
}
