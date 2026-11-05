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
        await store.setStatus(.submitted, ids: [sent.id])
        let queue = fixture.makeQueue(store: store)

        try await queue.holdPendingCaptures()

        #expect(await store.all().map(\.status) == [.submitted, .failed])
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

    private func waitUntil(_ condition: @Sendable () async -> Bool) async {
        while await !condition() {
            await Task.yield()
        }
    }
}
