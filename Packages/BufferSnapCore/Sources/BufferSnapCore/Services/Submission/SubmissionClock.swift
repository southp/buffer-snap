import Foundation

/// The time as `SubmissionQueue` sees it, so tests don't have to wait out a back-off.
public protocol SubmissionClock: Sendable {
    var now: Date { get }
    /// Throws if the task waiting is cancelled.
    func sleep(for seconds: TimeInterval) async throws
}

/// The real clock. `Task.sleep` counts time the iPhone spends asleep, so a wait that ended while the app was suspended
/// is over as soon as the app runs again.
public struct SystemSubmissionClock: SubmissionClock {
    public init() {}

    public var now: Date {
        Date()
    }

    public func sleep(for seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}

/// How long to wait after failures in a row: 5 seconds, then 10, 20, and so on up to 15 minutes.
public struct SubmissionBackoff: Sendable {
    public var base: TimeInterval = 5
    public var limit: TimeInterval = 15 * 60

    public init() {}

    public func delay(afterFailures failures: Int) -> TimeInterval {
        min(limit, base * pow(2, Double(max(failures, 1) - 1)))
    }
}
