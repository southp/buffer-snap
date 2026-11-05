import Foundation
import Synchronization

/// How close together captures must be to become one idea, and so how long a batch waits after its last capture.
public protocol BatchWindowSetting: Sendable {
    /// In seconds. 0 is off: each capture goes at once, by itself.
    var window: TimeInterval { get }
    func setWindow(_ window: TimeInterval)
}

/// The values the setting offers.
public enum BatchWindow {
    public static let off: TimeInterval = 0
    public static let standard: TimeInterval = 5 * 60
    public static let options: [TimeInterval] = [off, 1 * 60, 2 * 60, standard, 10 * 60, 15 * 60]
}

/// A `BatchWindowSetting` that lasts as long as it does, for tests and previews.
public final class InMemoryBatchWindowSetting: BatchWindowSetting {
    private let current: Mutex<TimeInterval>

    public init(window: TimeInterval = BatchWindow.standard) {
        current = Mutex(window)
    }

    public var window: TimeInterval {
        current.withLock { $0 }
    }

    public func setWindow(_ window: TimeInterval) {
        current.withLock { $0 = window }
    }
}

/// The setting in `UserDefaults`. Only the app's process sends, so its own defaults are enough, and nothing needs it in
/// the App Group.
///
/// A launch argument overrides it, as with any default: `-batchWindow 20` makes a simulator's batch go after 20
/// seconds.
public struct UserDefaultsBatchWindowSetting: BatchWindowSetting {
    private static let key = "batchWindow"
    // A name, as `UserDefaults` isn't `Sendable`. Asking for it again each time costs nothing, as it's cached.
    private let suiteName: String?

    /// `suiteName` picks other defaults than the app's own, for tests.
    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    public var window: TimeInterval {
        guard defaults.object(forKey: Self.key) != nil else {
            return BatchWindow.standard
        }
        return max(defaults.double(forKey: Self.key), BatchWindow.off)
    }

    public func setWindow(_ window: TimeInterval) {
        defaults.set(window, forKey: Self.key)
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }
}
