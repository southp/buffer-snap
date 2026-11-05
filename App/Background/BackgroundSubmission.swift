import BackgroundTasks
import BufferSnapCore
import OSLog
import UIKit

/// What keeps captures moving when the app isn't on screen. None of this can run on a simulator:
/// `docs/decisions/44-background-sending.md`.
enum BackgroundSubmission {
    /// Also in `BGTaskSchedulerPermittedIdentifiers` in `App/Info.plist`.
    static let taskIdentifier = "me.southp.buffersnap.submit"

    /// Asks iOS to wake the app in the background, at a time of its choosing. Asking again replaces the last request.
    /// A simulator refuses this, and the app works the same without it.
    static func scheduleWakeUp() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger().notice("Can't schedule a background wake-up: \(error, privacy: .public)")
        }
    }

    /// Asks iOS for time to finish sending as the app leaves the screen, so saving an idea and locking the phone at
    /// once doesn't freeze the request halfway, which is how a duplicate happens.
    @MainActor
    static func finishSending(on queue: SubmissionQueue) {
        let time = ExtraBackgroundTime()
        time.begin()
        Task {
            await queue.run()
            time.end()
        }
    }
}

/// One stretch of extra time from iOS, which must be ended exactly once.
@MainActor
private final class ExtraBackgroundTime {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    func begin() {
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Finish sending") { [self] in
            end()
        }
    }

    func end() {
        guard identifier != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
