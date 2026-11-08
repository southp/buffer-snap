import Foundation

/// Whether everything reached Buffer, at a glance: `docs/decisions/46-sync-now.md`.
public enum SyncStatus: Sendable, Equatable {
    /// There are no captures at all.
    case nothingYet
    /// Everything that can go is in Buffer.
    case allSent
    /// `count` captures will go by themselves. `nextSendAt` is when the next open batch goes, if one is counting down.
    case waiting(count: Int, nextSendAt: Date?)
    /// `count` captures are waiting, and the last try couldn't reach Buffer. They go once there's a connection.
    case offline(count: Int)
    /// `count` captures didn't go, and only Resend sends them. `waiting` more go by themselves.
    case failed(count: Int, waiting: Int)

    /// The status of `batches` at `now`. `isOffline` is whether the queue's last pass couldn't reach Buffer.
    public init(batches: [CaptureBatch], isOffline: Bool, now: Date) {
        let waiting = Self.waitingCount(of: batches)
        let failed = batches.filter { $0.state == .failed }.reduce(0) { count, batch in
            count + batch.captures.count { $0.status == .failed }
        }
        if failed > 0 {
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

    /// Whether Sync now has anything to send.
    public var canSyncNow: Bool {
        switch self {
        case .waiting, .offline:
            true
        case .failed(_, let waiting):
            waiting > 0
        case .nothingYet, .allSent:
            false
        }
    }

    /// How many of `captures` will go to Buffer by themselves: pending ones that can become an idea.
    public static func waitingCount(of captures: [Capture]) -> Int {
        waitingCount(of: CaptureBatch.batches(of: captures, window: 0))
    }

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
