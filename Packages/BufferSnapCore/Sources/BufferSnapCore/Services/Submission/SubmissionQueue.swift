import Foundation
import OSLog

/// Sends pending captures to Buffer, one idea at a time, and keeps their status up to date.
///
/// Anything may call `run()` at any time. Only one send is ever in flight, as two would create the same idea twice.
/// What each failure leads to, and why: `docs/decisions/44-what-gets-retried.md` and
/// `docs/decisions/44-duplicate-ideas.md`.
///
/// There's one of these, in the app's process, because it asks `AuthService` for tokens: see `AuthService`.
public actor SubmissionQueue {
    public enum Event: Sendable, Equatable {
        /// A capture's status changed.
        case capturesChanged
        /// A send needs the user to sign in again.
        case sessionLost
    }

    /// How a pass through the queue goes on, or why it stops.
    private enum Step: Equatable {
        case keepGoing
        case nothingLeft
        case retryLater
        case rateLimited(retryAfter: TimeInterval?)
        case sessionLost
    }

    /// Server failures one capture gets before it shows as failed. Buffer may have acted on each of them, so without a
    /// limit a server that creates the idea and then answers 500 would fill someone's Buffer.
    public static let maxServerFailures = 5
    /// Rejected tokens in one pass before it stops. Buffer rejecting a brand new token won't change in a moment.
    private static let maxTokenRejections = 2

    private let store: any CaptureStore
    private let auth: any AuthService
    private let client: any BufferClient
    private let planner: any SubmissionPlanner
    private let clock: any SubmissionClock
    private let backoff: SubmissionBackoff
    private let jitter: @Sendable () -> TimeInterval

    private var drainTask: Task<Void, Never>?
    private var isRunRequested = false
    private var wakeTask: Task<Void, Never>?
    private var rateLimitedUntil: Date?
    private var failuresInARow = 0
    private var serverFailures: [Capture.ID: Int] = [:]
    /// Buffer has these, but saving that failed. Sending them again would be a sure duplicate, so nothing else goes
    /// until a write works.
    private var sentButUnsaved: Set<Capture.ID> = []
    private let subscribers = EventSubscribers<Event>()

    // Looked up for each pass and never kept, so no session can use another's. It costs one request per pass.
    private var organizationID: String?
    private var tokenRejections = 0

    public init(
        store: any CaptureStore,
        auth: any AuthService,
        client: any BufferClient,
        planner: any SubmissionPlanner = OneIdeaPerCapture(),
        clock: any SubmissionClock = SystemSubmissionClock(),
        backoff: SubmissionBackoff = SubmissionBackoff(),
        // The guide's "little jitter": clients waiting out the same limit shouldn't all come back at the same instant.
        jitter: @escaping @Sendable () -> TimeInterval = { .random(in: 0...5) }
    ) {
        self.store = store
        self.auth = auth
        self.client = client
        self.planner = planner
        self.clock = clock
        self.backoff = backoff
        self.jitter = jitter
    }

    /// Sends what's pending, unless Buffer has asked to wait. A back-off doesn't stop this: only a rate limit does.
    ///
    /// Returns when the pass ends or the caller is cancelled. Cancelling only stops the waiting, not the send, because
    /// a request Buffer may have acted on shouldn't be abandoned just because a background task ran out of time.
    public func run() async {
        guard let task = startDrain() else {
            return
        }
        await task.waitUnlessCancelled()
    }

    /// Makes a failed capture pending again and starts sending it, without waiting for that to end.
    public func resend(_ id: Capture.ID) async throws {
        serverFailures[id] = nil
        try await store.setStatus(.pending, ids: [id])
        subscribers.publish(.capturesChanged)
        _ = startDrain()
    }

    /// Turns every pending capture into a failed one, so it goes nowhere until someone taps Resend. Called before a
    /// sign-in, which might be someone else's: `docs/decisions/44-hold-captures-at-sign-in.md`.
    public func holdPendingCaptures() async throws {
        let pending = try await store.all().filter { $0.status == .pending }
        guard !pending.isEmpty else {
            return
        }
        try await store.setStatus(.failed, ids: Set(pending.map(\.id)))
        subscribers.publish(.capturesChanged)
    }

    /// What's happening, from now until the stream's consumer goes away.
    public nonisolated func events() -> AsyncStream<Event> {
        subscribers.subscribe()
    }

    // MARK: - A pass through the queue

    private func startDrain() -> Task<Void, Never>? {
        if let rateLimitedUntil, clock.now < rateLimitedUntil {
            return nil
        }
        if let drainTask {
            // It may already have read the store, so a capture saved just now could be missed without this.
            isRunRequested = true
            return drainTask
        }
        // Its own task, so a cancelled caller can't cancel a request in flight.
        let task = Task {
            await drain()
        }
        drainTask = task
        return task
    }

    private func drain() async {
        organizationID = nil
        tokenRejections = 0
        var step = Step.keepGoing
        while step == .keepGoing {
            step = await sendNextHandlingFailures()
            if step == .nothingLeft, isRunRequested {
                isRunRequested = false
                step = .keepGoing
            }
        }
        finish(with: step)
    }

    private func sendNextHandlingFailures() async -> Step {
        do {
            return try await sendNext()
        } catch let error as AuthError where error.requiresSignIn {
            return .sessionLost
        } catch {
            // Offline during a refresh, Buffer's token endpoint having a bad moment, or a store that can't be read or
            // written. Nothing there says anything about the captures.
            Logger.submission.error("Stopping for now: \(String(describing: type(of: error)), privacy: .public)")
            return .retryLater
        }
    }

    private func sendNext() async throws -> Step {
        try await saveWhatWasSent()
        // Nothing to send means no token and no request.
        guard let upcoming = try await nextSubmission() else {
            return .nothingLeft
        }
        let token = try await auth.validAccessToken()
        var sending: Submission?
        do {
            let organizationID = try await organizationID(token: token)
            // Read again now that there's a token: a capture held for an earlier sign-in mustn't leave on this one.
            guard let submission = try await nextSubmission() else {
                return .nothingLeft
            }
            sending = submission
            try await client.createIdea(text: submission.text, organizationID: organizationID, accessToken: token)
            sentButUnsaved.formUnion(submission.captureIDs)
        } catch let error as BufferError {
            return try await recover(from: error, token: token, sending: sending, upcoming: upcoming)
        }
        Logger.submission.info("Sent an idea")
        failuresInARow = 0
        tokenRejections = 0
        try await saveWhatWasSent()
        return .keepGoing
    }

    private func organizationID(token: String) async throws -> String {
        if let organizationID {
            return organizationID
        }
        let fetched = try await client.firstOrganizationID(accessToken: token)
        organizationID = fetched
        return fetched
    }

    private func recover(
        from error: BufferError,
        token: String,
        sending: Submission?,
        upcoming: Submission
    ) async throws -> Step {
        switch error {
        case .unauthorized:
            await auth.accessTokenRejected(token)
            tokenRejections += 1
            return tokenRejections < Self.maxTokenRejections ? .keepGoing : .retryLater
        case .rateLimited(let retryAfter):
            return .rateLimited(retryAfter: retryAfter)
        case .connection:
            return .retryLater
        case .serverTrouble:
            // Asking for the organization creates nothing, so only a failed send counts against a capture.
            guard let sending else {
                return .retryLater
            }
            return try await countServerFailure(of: sending)
        case .rejected(let reason):
            try await markFailed(sending ?? upcoming, reason: reason)
            return .keepGoing
        }
    }

    private func countServerFailure(of submission: Submission) async throws -> Step {
        var failures = 0
        for id in submission.captureIDs {
            serverFailures[id, default: 0] += 1
            failures = max(failures, serverFailures[id, default: 0])
        }
        guard failures >= Self.maxServerFailures else {
            return .retryLater
        }
        try await markFailed(submission, reason: "Too many server failures")
        return .keepGoing
    }

    private func markFailed(_ submission: Submission, reason: String) async throws {
        Logger.submission.error("Marking a capture failed: \(reason, privacy: .public)")
        try await store.setStatus(.failed, ids: Set(submission.captureIDs))
        for id in submission.captureIDs {
            serverFailures[id] = nil
        }
        subscribers.publish(.capturesChanged)
    }

    private func saveWhatWasSent() async throws {
        guard !sentButUnsaved.isEmpty else {
            return
        }
        try await store.setStatus(.submitted, ids: sentButUnsaved)
        for id in sentButUnsaved {
            serverFailures[id] = nil
        }
        sentButUnsaved.removeAll()
        subscribers.publish(.capturesChanged)
    }

    /// Reads the store every time, so a capture deleted or held since the last send doesn't go.
    private func nextSubmission() async throws -> Submission? {
        let pending = try await store.all()
            .filter { $0.status == .pending }
            .sorted { $0.createdAt < $1.createdAt }
        return planner.nextSubmission(from: pending)
    }

    // MARK: - Ending a pass

    /// Doesn't suspend, so no `run()` can slip in between the last read of the store and `drainTask` being cleared.
    private func finish(with step: Step) {
        drainTask = nil
        isRunRequested = false
        switch step {
        case .keepGoing, .nothingLeft:
            failuresInARow = 0
            wakeTask?.cancel()
            wakeTask = nil
        case .retryLater:
            failuresInARow += 1
            scheduleWake(after: backoff.delay(afterFailures: failuresInARow) + jitter())
        case .rateLimited(let retryAfter):
            failuresInARow += 1
            let wait = (retryAfter ?? backoff.delay(afterFailures: failuresInARow)) + jitter()
            Logger.submission.notice("Rate limited for \(wait, privacy: .public)s")
            rateLimitedUntil = clock.now.addingTimeInterval(wait)
            scheduleWake(after: wait)
        case .sessionLost:
            wakeTask?.cancel()
            wakeTask = nil
            subscribers.publish(.sessionLost)
        }
    }

    private func scheduleWake(after delay: TimeInterval) {
        wakeTask?.cancel()
        wakeTask = Task {
            do {
                try await clock.sleep(for: delay)
            } catch {
                return
            }
            wake()
        }
    }

    private func wake() {
        rateLimitedUntil = nil
        _ = startDrain()
    }
}
