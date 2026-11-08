import Foundation

/// Where a dictation started outside the app shows itself: the Live Activity, in the app.
///
/// Main-actor and synchronous, because a Live Activity must be requested before the intent that started listening
/// returns, and requesting one is synchronous. Updates that take time are the implementation's to queue, in order.
@MainActor
public protocol DictationDisplay: AnyObject {
    /// Shows `status`, starting the Live Activity if there's none. Does nothing if Live Activities are off.
    func show(_ status: DictationStatus)
    /// Takes the Live Activity away.
    func dismiss()
}

/// Keeps the app's process running once the mic is off, when background audio no longer does, so the last words, the
/// save and the send can finish. The app's is a UIKit background task.
@MainActor
public protocol DictationKeepAlive: AnyObject {
    func begin()
    func end()
}

/// The time as `HandsFreeDictationSession` sees it, so tests don't have to wait out the silence or the time limit.
public protocol DictationClock: Sendable {
    var now: Date { get }
    /// Throws if the task waiting is cancelled.
    func sleep(for seconds: TimeInterval) async throws
}

/// The real clock.
public struct SystemDictationClock: DictationClock {
    public init() {}

    public var now: Date {
        Date()
    }

    public func sleep(for seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(max(0, seconds)))
    }
}

/// A `DictationDisplay` that keeps what it's told, for tests and previews.
@MainActor
public final class MockDictationDisplay: DictationDisplay {
    /// Every status shown, in order.
    public private(set) var shown: [DictationStatus] = []
    public private(set) var dismissCount = 0

    public init() {}

    public func show(_ status: DictationStatus) {
        shown.append(status)
    }

    public func dismiss() {
        dismissCount += 1
    }
}

/// A `DictationKeepAlive` that counts, for tests and previews.
@MainActor
public final class MockDictationKeepAlive: DictationKeepAlive {
    public private(set) var beginCount = 0
    public private(set) var endCount = 0

    public init() {}

    /// Whether it's holding the process awake now.
    public var isHolding: Bool {
        beginCount > endCount
    }

    public func begin() {
        beginCount += 1
    }

    public func end() {
        endCount += 1
    }
}
