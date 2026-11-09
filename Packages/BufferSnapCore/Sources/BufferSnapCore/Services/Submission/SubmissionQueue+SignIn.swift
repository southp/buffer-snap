import Foundation
import OSLog

// What the queue does around signing in: `docs/decisions/68-ideas-at-sign-in.md`.
extension SubmissionQueue {
    /// Turns every pending capture into a held one, so it goes nowhere until someone says it should. Called before a
    /// sign-in, which might be someone else's, and again once it's done for anything saved during it. Held captures
    /// are `.failed` with `.heldAtSignIn`, so a crash anywhere in between can't leave a new session with captures
    /// still pending: `docs/decisions/68-ideas-at-sign-in.md`.
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

    /// How many held ideas a sign-in should ask about. Each batch is one idea, and one with nothing to send isn't
    /// counted.
    public func heldIdeaCount() async throws -> Int {
        try await heldBatches().count
    }

    /// Sends every held idea, for "Send N ideas to this account?". Each is a batch, so each stays one idea.
    public func sendHeldIdeas() async throws {
        for batch in try await heldBatches() {
            try await resend(batch.id)
        }
    }

    /// Puts held captures back to waiting, for when nobody ended up signed in, such as a cancelled sign-in. Nothing can
    /// leave without a session, and the next sign-in holds them again.
    public func releaseHeldCaptures() async throws {
        let held = try await heldCaptures()
        guard !held.isEmpty else {
            return
        }
        try await store.setStatus(.pending, ids: Set(held.map(\.id)))
        subscribers.publish(.capturesChanged)
    }

    private func heldCaptures() async throws -> [Capture] {
        try await store.all().filter { $0.status == .failed && $0.failure == .heldAtSignIn }
    }

    private func heldBatches() async throws -> [CaptureBatch] {
        planner.batches(of: try await heldCaptures()).filter { $0.text != nil }
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
