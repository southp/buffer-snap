import BufferSnapCore
import UIKit

/// Keeps the app running once the mic is off, through a UIKit background task.
///
/// While listening, the `audio` background mode keeps the app running. Once the audio stops it doesn't, and the last
/// words, the save, the send and taking the Live Activity away still need a few seconds.
@MainActor
final class BackgroundTaskKeepAlive: DictationKeepAlive {
    private var task = UIBackgroundTaskIdentifier.invalid

    func begin() {
        guard task == .invalid else {
            return
        }
        // iOS calls this on the main thread and expects the task ended before it returns, or it may kill the app, so
        // this ends it there and then rather than in a `Task` that runs later.
        task = UIApplication.shared.beginBackgroundTask(withName: "Dictation") { [weak self] in
            MainActor.assumeIsolated {
                self?.end()
            }
        }
    }

    func end() {
        guard task != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }
}
