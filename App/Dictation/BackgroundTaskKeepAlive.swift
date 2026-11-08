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
        task = UIApplication.shared.beginBackgroundTask(withName: "Dictation") { [weak self] in
            Task { @MainActor in
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
