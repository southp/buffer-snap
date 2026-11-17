// What the queue tells whoever is listening: the list, and `AppModel` about a lost session.
extension SubmissionQueue {
    public enum Event: Sendable, Equatable {
        /// A capture's status changed.
        case capturesChanged
        /// Buffer ended the session. Never having signed in doesn't count: that's a quiet wait.
        case sessionLost
        /// `isOffline` changed.
        case reachabilityChanged
        /// Buffer asked to wait, or the wait is over: `rateLimitedUntil` changed.
        case rateLimitChanged
    }

    /// What's happening, from now until the stream's consumer goes away.
    public nonisolated func events() -> AsyncStream<Event> {
        subscribers.subscribe()
    }
}
