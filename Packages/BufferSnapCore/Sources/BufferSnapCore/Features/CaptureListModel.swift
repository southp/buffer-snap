import Foundation
import Observation

/// The list of captures, newest first, how far they are on their way to Buffer, and the actions on them.
@Observable
@MainActor
public final class CaptureListModel {
    /// Something the list couldn't do, to show until the next try. Each is a store that can't be read or written.
    public enum Problem: Sendable, Equatable {
        /// The list shows what was last read, which may be out of date.
        case couldNotLoad
        case couldNotDelete
        case couldNotResend
        /// Send now or Sync now couldn't close what's open, so nothing changed.
        case couldNotSend
        /// The clear didn't happen, so everything is still listed.
        case couldNotClear
    }

    /// Stored captures, newest first. Empty until `load()` finishes.
    public private(set) var captures: [Capture] = [] {
        didSet {
            batches = submissions.batches(of: captures).reversed()
        }
    }
    /// The same captures in the batches they'll go or went in, newest first. Inside a batch, they're in the order they
    /// were made, which is how they read in the idea.
    public private(set) var batches: [CaptureBatch] = []
    /// Whether the queue's last pass couldn't reach Buffer, as of the last load.
    public private(set) var isOffline = false
    /// Until when Buffer asked the queue to wait, as of the last load, or `nil` if it didn't.
    public private(set) var rateLimitedUntil: Date?
    /// Whether a Sync now is running.
    public private(set) var isSyncing = false
    /// What went wrong last, until the next try of the same kind works.
    public private(set) var problem: Problem?
    /// How many ideas have gone in full and could be cleared, counted as the list shows them: a batch of three captures
    /// is one idea. A batch with anything unsent isn't one of them.
    public var clearableIdeaCount: Int {
        batches.count { $0.state == .submitted }
    }

    private let store: any CaptureStore
    private let submissions: SubmissionQueue

    public init(store: any CaptureStore, submissions: SubmissionQueue) {
        self.store = store
        self.submissions = submissions
    }

    /// Whether everything reached Buffer, at `now`.
    public func syncStatus(at now: Date) -> SyncStatus {
        SyncStatus(batches: batches, isOffline: isOffline, rateLimitedUntil: rateLimitedUntil, now: now)
    }

    /// Reads every capture from the store, and whether the queue is offline or rate limited.
    public func load() async {
        isOffline = await submissions.isOffline
        rateLimitedUntil = await submissions.rateLimitedUntil
        do {
            captures = try await store.all().sorted { $0.createdAt > $1.createdAt }
            if problem == .couldNotLoad {
                problem = nil
            }
        } catch {
            // Keep the last loaded list, and say it may be out of date.
            problem = .couldNotLoad
        }
    }

    /// Loads, then again each time a send changes a capture's status or whether Buffer can be reached, until the
    /// calling task is cancelled.
    public func loadAndFollowChanges() async {
        // Listen first, so a change while loading isn't missed.
        let events = submissions.events()
        await load()
        for await event in events where event != .sessionLost {
            await load()
        }
    }

    /// Sends a failed batch again, as one idea.
    public func resend(_ batch: CaptureBatch) async {
        await attempt(failingWith: .couldNotResend) {
            try await submissions.resend(batch.id)
        }
    }

    /// Sends the open batch without waiting for its window to end.
    public func sendNow() async {
        await attempt(failingWith: .couldNotSend) {
            try await submissions.sendNow()
        }
    }

    /// Sends everything that can go, without waiting for any window, and returns once that pass is over. Failed batches
    /// stay as they are, each with its own Resend. While Buffer has asked to wait, it does nothing, so "Syncing…"
    /// doesn't flash up for a pass that can't start.
    public func syncNow() async {
        guard !isSyncing else {
            return
        }
        // Ask the queue: a wait may have started since the last load, before its event reached the list.
        rateLimitedUntil = await submissions.rateLimitedUntil
        guard !isSyncing, !isRateLimited else {
            return
        }
        isSyncing = true
        defer {
            isSyncing = false
        }
        await attempt(failingWith: .couldNotSend) {
            try await submissions.syncNow()
        }
    }

    /// Deletes `capture` from the store, then from the list. If it set when its batch goes, that time moves.
    public func delete(_ capture: Capture) async {
        do {
            try await store.delete(id: capture.id)
            captures.removeAll { $0.id == capture.id }
            problem = nil
            await submissions.replan()
        } catch {
            // Keep it listed, since the store still has it.
            problem = .couldNotDelete
        }
    }

    /// Removes every submitted capture from this iPhone, in one write. They stay in Buffer. Only submitted captures go,
    /// so a batch that's partly unsent loses just its sent part, and the rest is listed and resent as before.
    public func clearSubmitted() async {
        await attempt(failingWith: .couldNotClear) {
            try await store.deleteSubmitted()
            await submissions.replan()
        }
    }

    /// Whether the rate limit from the last load is still on, by the queue's clock.
    private var isRateLimited: Bool {
        guard let rateLimitedUntil else {
            return false
        }
        return submissions.clock.now < rateLimitedUntil
    }

    /// Runs `action`, then reloads. If it throws, nothing changed, and `failure` says so.
    private func attempt(failingWith failure: Problem, _ action: () async throws -> Void) async {
        do {
            try await action()
            problem = nil
            await load()
        } catch {
            problem = failure
        }
    }
}
