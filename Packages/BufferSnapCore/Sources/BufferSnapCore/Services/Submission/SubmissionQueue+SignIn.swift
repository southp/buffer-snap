import Foundation
import OSLog

// What the queue does around signing in: `docs/decisions/68-ideas-at-sign-in.md`.
extension SubmissionQueue {
    /// Turns every pending capture into a failed one, so it goes nowhere until someone taps Resend. Called before a
    /// sign-in, which might be someone else's: `docs/decisions/44-hold-captures-at-sign-in.md`.
    ///
    /// What's open closes first, in its own write, so a held batch stays together and nothing saved later can join it.
    /// A crash between the two writes leaves it closed and pending, and the next sign-in holds it again.
    public func holdPendingCaptures() async throws {
        let pending = try await store.pendingCaptures()
        guard !pending.isEmpty else {
            return
        }
        try await store.closeOpenBatches(planner.batches(of: pending))
        try await store.setStatus(.failed, failure: .heldAtSignIn, ids: Set(pending.map(\.id)))
        subscribers.publish(.capturesChanged)
    }

    /// Nobody is signed in, so nothing can leave, and that isn't a failure of any kind. Batches still close by the
    /// same clock, so each becomes one idea after sign-in: `docs/decisions/68-batches-while-signed-out.md`.
    ///
    /// Returns when the next open batch's window ends, if one is still open.
    func closeDueBatchesWhileSignedOut() async -> Date? {
        do {
            let batches = planner.batches(of: try await store.pendingCaptures())
            let now = clock.now
            let due = batches.filter { batch in
                if case .open(let sendsAt) = batch.state {
                    return sendsAt <= now
                }
                return false
            }
            try await store.closeOpenBatches(due)
            return batches.compactMap { batch -> Date? in
                if case .open(let sendsAt) = batch.state, sendsAt > now {
                    return sendsAt
                }
                return nil
            }.min()
        } catch {
            // Nothing is lost: the next pass tries again, and nothing can leave in the meantime anyway.
            Logger.submission.error(
                "Can't close batches while signed out: \(String(describing: type(of: error)), privacy: .public)")
            return nil
        }
    }
}
