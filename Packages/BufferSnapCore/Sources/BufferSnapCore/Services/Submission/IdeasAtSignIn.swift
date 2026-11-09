/// What happens to captures around a sign-in: everything waiting is held first, and only what the person confirms goes
/// to the account they signed in to. `SubmissionQueue` does it; a protocol so `AppModel`'s tests can stand it in.
/// Why: `docs/decisions/68-ideas-at-sign-in.md`.
public protocol IdeasAtSignIn: Sendable {
    /// Before a sign-in starts, and again once it's done. Throwing stops a sign-in that hasn't started.
    func holdPendingCaptures() async throws
    /// How many held ideas to ask about after a sign-in.
    func heldIdeaCount() async throws -> Int
    /// "Send N ideas to this account?" was answered yes.
    func sendHeldIdeas() async throws
    /// Nobody ended up signed in, so held captures can go back to waiting.
    func releaseHeldCaptures() async throws
}

extension SubmissionQueue: IdeasAtSignIn {}

/// Nothing waits at sign-in, for tests and previews that don't care about it.
public struct NoIdeasAtSignIn: IdeasAtSignIn {
    public init() {}

    public func holdPendingCaptures() async throws {}

    public func heldIdeaCount() async throws -> Int {
        0
    }

    public func sendHeldIdeas() async throws {}

    public func releaseHeldCaptures() async throws {}
}
