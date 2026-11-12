import Foundation

/// Whether everything reached Buffer, at a glance: `docs/decisions/105-say-when-buffer-asks-to-wait.md`.
public enum SyncStatus: Sendable, Equatable {
    /// There are no captures at all.
    case nothingYet
    /// Everything that can go is in Buffer.
    case allSent
    /// `count` captures will go by themselves. `nextSendAt` is when the next open batch goes, if one is counting down.
    case waiting(count: Int, nextSendAt: Date?)
    /// `count` captures are waiting, and the last try couldn't reach Buffer. They go once there's a connection.
    case offline(count: Int)
    /// `count` captures are waiting, and Buffer asked BufSnap not to send anything before `until`. They go then.
    case rateLimited(count: Int, until: Date)
    /// `count` captures didn't go, and only Resend sends them. `waiting` more go by themselves.
    case failed(count: Int, waiting: Int)

    /// The status of `batches` at `now`. `isOffline` is whether the queue's last pass couldn't reach Buffer, and
    /// `rateLimitedUntil` is until when Buffer asked it to wait, if it did.
    ///
    /// A rate limit with something waiting comes first: nothing moves until it ends, a Resend included, and each failed
    /// batch still says so in its own header.
    public init(batches: [CaptureBatch], isOffline: Bool, rateLimitedUntil: Date? = nil, now: Date) {
        let waiting = Self.waitingCount(of: batches)
        let failed = batches.filter { $0.state == .failed }.reduce(0) { count, batch in
            count + batch.captures.count { $0.status == .failed }
        }
        if waiting > 0, let rateLimitedUntil, now < rateLimitedUntil {
            self = .rateLimited(count: waiting, until: rateLimitedUntil)
        } else if failed > 0 {
            self = .failed(count: failed, waiting: waiting)
        } else if waiting > 0 && isOffline {
            self = .offline(count: waiting)
        } else if waiting > 0 {
            let countingDown = batches.compactMap { batch -> Date? in
                guard case .open(let sendsAt) = batch.state, batch.isWaiting(at: now) else {
                    return nil
                }
                return sendsAt
            }
            self = .waiting(count: waiting, nextSendAt: countingDown.min())
        } else if batches.isEmpty {
            self = .nothingYet
        } else {
            self = .allSent
        }
    }

    /// Whether Sync now has anything to send, and Buffer will take it now.
    public var canSyncNow: Bool {
        switch self {
        case .waiting, .offline:
            true
        case .failed(_, let waiting):
            waiting > 0
        case .nothingYet, .allSent, .rateLimited:
            false
        }
    }

    /// How many captures in `batches` will go to Buffer by themselves: pending ones that can become an idea.
    private static func waitingCount(of batches: [CaptureBatch]) -> Int {
        batches.reduce(0) { count, batch in
            switch batch.state {
            case .open, .closed:
                count + batch.captures.count { $0.status == .pending }
            case .submitted, .failed, .unsendable:
                count
            }
        }
    }
}
