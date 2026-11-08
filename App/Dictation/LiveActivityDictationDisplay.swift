import ActivityKit
import BufferSnapCore
import OSLog

/// Shows a dictation started outside the app as a Live Activity, on the Lock Screen and in the Dynamic Island.
///
/// Requesting the activity is synchronous, so it exists before the intent that started listening returns. Updating
/// and ending it aren't, so they go through one queue and land in order: a late update can't bring back a countdown
/// after "Saved". New words go at most twice a second, which the #57 spike showed keeps up with speech.
@MainActor
final class LiveActivityDictationDisplay: DictationDisplay {
    private enum Change: Sendable {
        case update(activityID: String, status: DictationStatus)
        case end(activityIDs: [String], status: DictationStatus?)
    }

    private static let wordsInterval: Duration = .milliseconds(500)

    private let changes: AsyncStream<Change>.Continuation
    private let logger = Logger()
    private var activityID: String?
    private var lastStatus: DictationStatus?
    private var lastWordsUpdate: ContinuousClock.Instant?
    /// New words that came too soon after the last, and go once the interval's up.
    private var heldBackWords: Task<Void, Never>?

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Change.self)
        changes = continuation
        Task.detached {
            for await change in stream {
                await Self.apply(change)
            }
        }
        // A dictation whose process was stopped can't end its own activity, so it would stay for hours, counting down.
        let leftovers = Activity<DictationActivityAttributes>.activities.map(\.id)
        if !leftovers.isEmpty {
            changes.yield(.end(activityIDs: leftovers, status: nil))
        }
    }

    func show(_ status: DictationStatus) {
        lastStatus = status
        guard let activityID else {
            request(status)
            return
        }
        heldBackWords?.cancel()
        heldBackWords = nil
        let clock = ContinuousClock()
        if status.isListening, let lastWordsUpdate, clock.now < lastWordsUpdate + Self.wordsInterval {
            heldBackWords = Task { [weak self] in
                try? await clock.sleep(until: lastWordsUpdate + Self.wordsInterval)
                guard !Task.isCancelled, let self, let status = self.lastStatus, status.isListening else {
                    return
                }
                self.send(status, to: activityID)
            }
            return
        }
        send(status, to: activityID)
    }

    func dismiss() {
        heldBackWords?.cancel()
        heldBackWords = nil
        guard let activityID else {
            return
        }
        self.activityID = nil
        lastWordsUpdate = nil
        changes.yield(.end(activityIDs: [activityID], status: lastStatus))
    }

    private func request(_ status: DictationStatus) {
        // Dictation works without it, just with nothing on screen.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        do {
            activityID = try Activity.request(
                attributes: DictationActivityAttributes(),
                content: ActivityContent(state: status, staleDate: nil)
            ).id
            lastWordsUpdate = ContinuousClock().now
        } catch {
            logger.error("Can't start the dictation's Live Activity: \(error)")
        }
    }

    private func send(_ status: DictationStatus, to activityID: String) {
        if status.isListening {
            lastWordsUpdate = ContinuousClock().now
        }
        changes.yield(.update(activityID: activityID, status: status))
    }

    // `Activity` isn't `Sendable`, so it's only touched here, off the main actor, and looked up by ID each time.

    private nonisolated static func apply(_ change: Change) async {
        switch change {
        case .update(let activityID, let status):
            for activity in Activity<DictationActivityAttributes>.activities where activity.id == activityID {
                await activity.update(ActivityContent(state: status, staleDate: nil))
            }
        case .end(let activityIDs, let status):
            let content = status.map { ActivityContent(state: $0, staleDate: nil) }
            for activity in Activity<DictationActivityAttributes>.activities where activityIDs.contains(activity.id) {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
    }
}
