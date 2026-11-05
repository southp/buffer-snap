import Foundation

/// One idea to create, and the captures it came from. The captures' statuses change together with its fate.
public struct Submission: Sendable, Equatable {
    public let batchID: Capture.BatchID
    public let captureIDs: [Capture.ID]
    public let text: String

    public init(batchID: Capture.BatchID, captureIDs: [Capture.ID], text: String) {
        self.batchID = batchID
        self.captureIDs = captureIDs
        self.text = text
    }
}

/// What to do about what's pending, as of now.
public enum SubmissionPlan: Sendable, Equatable {
    case send(Submission)
    /// Nothing goes until this moment, when a batch's window ends.
    case wait(until: Date)
    case nothing
}

/// Decides **what** to send next, one batch at a time. `SubmissionQueue` decides how, and its callers decide when to
/// try.
public struct SubmissionPlanner: Sendable {
    private let window: @Sendable () -> TimeInterval

    /// `window` is asked each time, so a changed setting applies at once to everything that's still open:
    /// `docs/decisions/45-changing-the-window.md`.
    public init(window: @escaping @Sendable () -> TimeInterval) {
        self.window = window
    }

    /// Each capture becomes its own idea.
    public static let noBatching = SubmissionPlanner { 0 }

    /// The batches `captures` make with the current window, oldest first.
    public func batches(of captures: [Capture]) -> [CaptureBatch] {
        CaptureBatch.batches(of: captures, window: window())
    }

    /// The next idea to create from `pending`, or how long nothing should go for.
    public func plan(pending: [Capture], now: Date) -> SubmissionPlan {
        var nextWindowEnd: Date?
        for batch in batches(of: pending) {
            switch batch.state {
            case .open(let sendsAt) where sendsAt > now:
                nextWindowEnd = min(sendsAt, nextWindowEnd ?? sendsAt)
            case .open, .closed:
                if let submission = batch.submission {
                    return .send(submission)
                }
            case .submitted, .failed, .unsendable:
                break
            }
        }
        return nextWindowEnd.map { .wait(until: $0) } ?? .nothing
    }
}

extension CaptureBatch {
    fileprivate var submission: Submission? {
        text.map { Submission(batchID: id, captureIDs: captures.map(\.id), text: $0) }
    }
}
