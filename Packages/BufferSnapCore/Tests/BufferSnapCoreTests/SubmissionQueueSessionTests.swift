import BufferSnapCore
import Foundation
import Testing

/// What a send does about tokens, sessions and sign-ins.
struct SubmissionQueueSessionTests {
    private let fixture = QueueFixture()
    private var server: FakeIdeasServer {
        fixture.server
    }
    private var clock: ManualSubmissionClock {
        fixture.clock
    }

    // MARK: - Tokens

    /// Goes through the real `OAuthAuthService`: a 401 forces a refresh, and the idea then goes with the new token.
    @Test func aRejectedTokenIsRefreshedAndTheSendRetried() async throws {
        let oauth = OAuthFixture()
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let auth = try await oauth.makeRestoredService(lifetime: 3600)
        let queue = fixture.makeQueue(store: store, auth: auth)
        await server.failIdeas(.answer(.tokenRejected))

        await queue.run()

        #expect(await oauth.refreshRequests().count == 1)
        #expect(await server.ideaTexts == ["An idea"])
        #expect(await store.all().map(\.status) == [.submitted])
    }

    /// Same for the organization lookup, which is usually what meets the old token first.
    @Test func aTokenRejectedDuringTheOrganizationLookupIsRefreshedToo() async throws {
        let oauth = OAuthFixture()
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let auth = try await oauth.makeRestoredService(lifetime: 3600)
        let queue = fixture.makeQueue(store: store, auth: auth)
        await server.failOrganizations(.answer(.tokenRejected))

        await queue.run()

        #expect(await oauth.refreshRequests().count == 1)
        #expect(await store.all().map(\.status) == [.submitted])
    }

    @Test func aRevokedSessionStopsAndKeepsTheCapturePending() async throws {
        let oauth = OAuthFixture()
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let auth = try await oauth.makeRestoredService(lifetime: 3600)
        let queue = fixture.makeQueue(store: store, auth: auth)
        let events = queue.events()
        await server.failIdeas(.answer(.tokenRejected))
        await oauth.server.revokeGrant()

        await queue.run()

        #expect(await store.all().map(\.status) == [.pending])
        #expect(await server.ideaRequests == 1)
        #expect(clock.sleeps.isEmpty)
        var iterator = events.makeAsyncIterator()
        #expect(await iterator.next() == .sessionLost)
    }

    @Test(arguments: [AuthError.notSignedIn, .sessionExpired])
    func withoutASessionNothingLeaves(error: AuthError) async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store, auth: StubAuthService(tokenError: error))

        await queue.run()

        #expect(await server.organizationRequests == 0)
        #expect(await store.all().map(\.status) == [.pending])
    }

    /// Never having signed in is the normal state of a fresh install, not a session someone lost.
    @Test func neverHavingSignedInIsAQuietWait() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store, auth: StubAuthService(tokenError: AuthError.notSignedIn))
        let events = queue.events()

        await queue.run()
        await queue.replan()

        #expect(await server.organizationRequests == 0)
        #expect(await server.ideaRequests == 0)
        #expect(await store.all().map(\.status) == [.pending])
        #expect(clock.sleeps.isEmpty)
        // The replan's own event comes first, so nothing was published before it.
        var iterator = events.makeAsyncIterator()
        #expect(await iterator.next() == .capturesChanged)
    }

    /// Signed out, batches keep closing by the same clock, so each is one idea after sign-in. Closing asks Buffer
    /// nothing, and the wait for the open one is the only thing scheduled.
    @Test func batchesKeepClosingByTheClockWhileSignedOut() async throws {
        let store = InMemoryCaptureStore()
        let auth = StubAuthService(tokenError: AuthError.notSignedIn)
        let queue = fixture.makeQueue(store: store, auth: auth, window: 300)
        for text in ["First", "Second", "Still open"] {
            try await store.add(fixture.capture(text))
            clock.advance(by: 301)
        }
        clock.advance(by: -301)

        await queue.run()

        let captures = try await store.all().sorted { $0.createdAt < $1.createdAt }
        #expect(captures.map { $0.batchID != nil } == [true, true, false])
        #expect(await server.organizationRequests == 0)
        #expect(await clock.waitForSleep(number: 1) == 300)
    }

    /// Only Buffer ending a session is worth telling the app about.
    @Test func anEndedSessionIsStillReported() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store, auth: StubAuthService(tokenError: AuthError.sessionExpired))
        let events = queue.events()

        await queue.run()

        var iterator = events.makeAsyncIterator()
        #expect(await iterator.next() == .sessionLost)
        #expect(await store.all().map(\.status) == [.pending])
    }

    /// Couldn't refresh for now, which says nothing about the capture or the session.
    @Test(arguments: [AuthError.network, .server, .storage])
    func aTokenFailureThatCanPassBacksOff(error: AuthError) async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store, auth: StubAuthService(tokenError: error))

        await queue.run()

        #expect(await clock.waitForSleep(number: 1) == 5)
        #expect(await store.all().map(\.status) == [.pending])
    }

    /// Failures from before the session ended say nothing about the next one.
    @Test func aSessionEndingStartsTheBackoffOver() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let auth = StubAuthService(hasSavedSession: true)
        let queue = fixture.makeQueue(store: store, auth: auth)
        await server.failIdeas(.offline)
        await queue.run()
        #expect(await clock.waitForSleep(number: 1) == 5)

        await auth.setTokenError(AuthError.sessionExpired)
        await queue.run()
        await auth.setTokenError(nil)
        await server.failIdeas(.offline)
        await queue.run()

        #expect(await clock.waitForSleep(number: 2) == 5)
    }

    /// A brand new token being rejected too won't change in a moment, so don't spin on it.
    @Test func aTokenRejectedTwiceBacksOffWithTheCapturePending() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.answer(.tokenRejected), .answer(.tokenRejected))

        await queue.run()

        #expect(await server.ideaRequests == 2)
        #expect(await clock.waitForSleep(number: 1) == 5)
        #expect(await store.all().map(\.status) == [.pending])
    }

    // MARK: - Holding captures at sign-in

    @Test func holdingTurnsOnlyPendingCapturesToFailed() async throws {
        let sent = Capture.text("Sent", at: 1)
        let store = InMemoryCaptureStore(seed: [sent, .text("Waiting", at: 2)])
        try await store.setStatus(.submitted, ids: [sent.id])
        let queue = fixture.makeQueue(store: store)

        try await queue.holdPendingCaptures()

        #expect(await store.all().map(\.status) == [.submitted, .failed])
        #expect(await store.all().map(\.failure) == [nil, .heldAtSignIn])
    }

    /// Once it's pending again, the reason it failed no longer applies.
    @Test func resendForgetsWhyItFailed() async throws {
        let capture = Capture.text("An idea")
        let store = InMemoryCaptureStore(seed: [capture])
        let queue = fixture.makeQueue(store: store)
        try await queue.holdPendingCaptures()

        try await queue.resend(capture.id)

        #expect(await store.all().map(\.failure) == [nil])
    }

    /// Whatever the new session is, a held capture only leaves when someone taps Resend.
    @Test func aHeldCaptureDoesntLeaveByItselfButResendSendsIt() async throws {
        let capture = Capture.text("An idea")
        let store = InMemoryCaptureStore(seed: [capture])
        let queue = fixture.makeQueue(store: store)

        try await queue.holdPendingCaptures()
        await queue.run()
        #expect(await server.ideaRequests == 0)

        try await queue.resend(capture.id)
        await waitUntil { await store.all().map(\.status) == [.submitted] }
        #expect(await server.ideaTexts == ["An idea"])
    }

    /// It left on the old session, so it reached the account it was meant for.
    @Test func aCaptureInFlightWhenHeldEndsUpSubmitted() async throws {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.holdNextIdea()

        async let run: Void = queue.run()
        await server.waitForHeldIdea()
        try await queue.holdPendingCaptures()
        await server.releaseIdea()
        await run

        #expect(await store.all().map(\.status) == [.submitted])
    }

    /// The next capture in line mustn't go once the hold has happened, whichever token is about to be used.
    @Test func aHoldDuringAPassStopsWhatsBehindIt() async throws {
        let store = InMemoryCaptureStore(seed: [.text("First", at: 1), .text("Second", at: 2)])
        let queue = fixture.makeQueue(store: store)
        await server.holdNextIdea()

        async let run: Void = queue.run()
        await server.waitForHeldIdea()
        try await queue.holdPendingCaptures()
        await server.releaseIdea()
        await run

        #expect(await server.ideaTexts == ["First"])
    }

    // MARK: - Ideas at sign-in

    /// A batch is one idea, and a capture with nothing to send isn't one at all.
    @Test func heldIdeasCountBatchesWithTextToSend() async throws {
        let batch = UUID()
        let refused = Capture.text("Refused", at: 4)
        let store = InMemoryCaptureStore(seed: [
            .text("First part", at: 1, batch: batch),
            .text("Second part", at: 2, batch: batch),
            .text("By itself", at: 3),
            Capture(kind: .photo, createdAt: Date(timeIntervalSinceReferenceDate: 5)),
            refused,
        ])
        try await store.setStatus(.failed, failure: .refused, ids: [refused.id])
        let queue = fixture.makeQueue(store: store)

        try await queue.holdPendingCaptures()

        #expect(try await queue.heldIdeaCount() == 2)
    }

    /// Yes sends what was held, one idea per batch, and doesn't touch a batch that failed for another reason.
    @Test func sendingWhatsHeldSendsOnlyThat() async throws {
        let batch = UUID()
        let refused = Capture.text("Refused", at: 3)
        let store = InMemoryCaptureStore(seed: [
            .text("First part", at: 1, batch: batch),
            .text("Second part", at: 2, batch: batch),
            refused,
        ])
        try await store.setStatus(.failed, failure: .refused, ids: [refused.id])
        let queue = fixture.makeQueue(store: store)
        try await queue.holdPendingCaptures()

        try await queue.sendHeldIdeas()
        await waitUntil { await server.ideaTexts.count == 1 }

        #expect(await server.ideaTexts == ["First part\n\nSecond part"])
        #expect(await store.all().first { $0.id == refused.id }?.failure == .refused)
    }

    /// Back to waiting, as if the sign-in never happened, and the batch it was closed into stays as it was.
    @Test func releasingPutsHeldCapturesBackToPending() async throws {
        let refused = Capture.text("Refused", at: 2)
        let store = InMemoryCaptureStore(seed: [.text("Waiting", at: 1), refused])
        try await store.setStatus(.failed, failure: .refused, ids: [refused.id])
        let queue = fixture.makeQueue(store: store)
        try await queue.holdPendingCaptures()

        try await queue.releaseHeldCaptures()

        #expect(await store.all().map(\.status) == [.pending, .failed])
        #expect(await store.all().map(\.failure) == [nil, .refused])
    }

    private func waitUntil(_ condition: @Sendable () async -> Bool) async {
        while await !condition() {
            await Task.yield()
        }
    }
}
