import BufferSnapCore
import Foundation
import Testing

/// The account query goes through the queue, so it shares the rate limit with sending ideas.
struct SubmissionQueueAccountTests {
    private let fixture = QueueFixture()

    @Test func theAccountComesFromBuffer() async throws {
        let queue = fixture.makeQueue(store: InMemoryCaptureStore())

        let account = try await queue.fetchAccount()

        #expect(account == BufferAccount(name: "Ada Lovelace", email: "ada@example.com"))
        #expect(await fixture.server.accountRequests == 1)
    }

    @Test func whileBufferAsksToWaitNothingIsAsked() async {
        let queue = fixture.makeQueue(store: InMemoryCaptureStore(seed: [.text("An idea")]))
        await fixture.server.failIdeas(.answer(.tooManyRequests(retryAfter: 60)))
        await queue.run()
        #expect(await queue.rateLimitedUntil != nil)

        await #expect(throws: BufferError.rateLimited(retryAfter: nil)) {
            try await queue.fetchAccount()
        }
        #expect(await fixture.server.accountRequests == 0)
    }

    /// Ideas wait it out too: Buffer counts both against the same limit.
    @Test func aRateLimitedAccountQueryMakesIdeasWait() async {
        let queue = fixture.makeQueue(store: InMemoryCaptureStore(seed: [.text("An idea")]))
        await fixture.server.failAccounts(.answer(.tooManyRequests(retryAfter: 60)))

        await #expect(throws: BufferError.rateLimited(retryAfter: 60)) {
            try await queue.fetchAccount()
        }
        await queue.run()

        #expect(await queue.rateLimitedUntil == fixture.clock.now.addingTimeInterval(60))
        #expect(await fixture.server.ideaRequests == 0)
    }

    /// Like an idea, a failed account query that isn't a rate limit leaves the queue free to send.
    @Test func otherFailuresDontStopIdeas() async {
        let queue = fixture.makeQueue(store: InMemoryCaptureStore(seed: [.text("An idea")]))
        await fixture.server.failAccounts(.answer(.serverError))

        await #expect(throws: BufferError.serverTrouble) {
            try await queue.fetchAccount()
        }
        await queue.run()

        #expect(await fixture.server.ideaTexts == ["An idea"])
    }

    /// No session means no token, so nothing reaches Buffer.
    @Test func withoutASessionNothingIsAsked() async {
        let queue = fixture.makeQueue(
            store: InMemoryCaptureStore(),
            auth: StubAuthService(tokenError: AuthError.notSignedIn)
        )

        await #expect(throws: AuthError.notSignedIn) {
            try await queue.fetchAccount()
        }
        #expect(await fixture.server.accountRequests == 0)
    }
}
