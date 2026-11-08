import BufferSnapCore
import Foundation
import Testing

struct SubmissionQueueFailureTests {
    private let fixture = QueueFixture()
    private var server: FakeIdeasServer {
        fixture.server
    }
    private var clock: ManualSubmissionClock {
        fixture.clock
    }

    // MARK: - Can't succeed

    /// Nothing about asking again would help, and it mustn't hold up what's behind it.
    @Test func aRefusedCaptureFailsAndTheNextOneStillGoes() async {
        let store = InMemoryCaptureStore(seed: [.text("Refused", at: 1), .text("Fine", at: 2)])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.answer(.invalidInput))

        await queue.run()

        #expect(await store.all().map(\.status) == [.failed, .submitted])
        #expect(await store.all().map(\.failure) == [.refused, nil])
        #expect(await server.ideaRequests == 2)
        #expect(clock.sleeps.isEmpty)
    }

    @Test func anAccountWithNoOrganizationFailsTheCapture() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.setOrganizations([])

        await queue.run()

        #expect(await store.all().map(\.status) == [.failed])
        #expect(await server.ideaRequests == 0)
    }

    @Test func aRefusedOrganizationLookupFailsTheCapture() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        let forbidden = #"{"data":null,"errors":[{"extensions":{"code":"FORBIDDEN"}}]}"#
        await server.failOrganizations(.answer(.init(body: forbidden)))

        await queue.run()

        #expect(await store.all().map(\.status) == [.failed])
    }

    // MARK: - Back-off

    /// Airplane mode: the capture waits, for as long as it takes, and never shows as failed.
    @Test func offlineStaysPendingAndBacksOffExponentially() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.offline, .offline, .offline)

        await queue.run()
        #expect(await clock.waitForSleep(number: 1) == 5)
        clock.finishLatestSleep()
        #expect(await clock.waitForSleep(number: 2) == 10)
        clock.finishLatestSleep()
        #expect(await clock.waitForSleep(number: 3) == 20)
        #expect(await store.all().map(\.status) == [.pending])

        clock.finishLatestSleep()
        await waitUntil { await store.all().map(\.status) == [.submitted] }
        #expect(await server.ideaTexts == ["An idea"])
    }

    @Test func theBackoffLevelsOffAtFifteenMinutes() {
        let backoff = SubmissionBackoff()

        let delays = (1...10).map { backoff.delay(afterFailures: $0) }

        #expect(delays == [5, 10, 20, 40, 80, 160, 320, 640, 900, 900])
    }

    /// The connectivity trigger, and any other, doesn't wait out a back-off.
    @Test func aNewRunDoesntWaitForTheBackoff() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.offline)
        await queue.run()

        await queue.run()

        #expect(await store.all().map(\.status) == [.submitted])
    }

    @Test func offlineStopsThePassInsteadOfTryingEveryCapture() async {
        let store = InMemoryCaptureStore(seed: [.text("One", at: 1), .text("Two", at: 2)])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.offline)

        await queue.run()

        #expect(await server.ideaRequests == 1)
    }

    /// Reading creates nothing, so nothing is at stake and the capture doesn't pay for it.
    @Test func aFailedOrganizationLookupNeverFailsTheCapture() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        for _ in 0..<(SubmissionQueue.maxServerFailures + 1) {
            await server.failOrganizations(.answer(.serverError))
            await queue.run()
            #expect(await store.all().map(\.status) == [.pending])
        }
        #expect(await server.ideaRequests == 0)
    }

    // MARK: - Rate limits

    @Test func aRateLimitIsWaitedOutToTheSecond() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.answer(.tooManyRequests(retryAfter: 753)))

        await queue.run()

        #expect(await clock.waitForSleep(number: 1) == 753)
        #expect(await store.all().map(\.status) == [.pending])
        clock.finishLatestSleep()
        await waitUntil { await store.all().map(\.status) == [.submitted] }
    }

    /// Unlike a back-off, Buffer asked for this, so foregrounding the app doesn't get around it.
    @Test func nothingGoesOutDuringARateLimit() async throws {
        let capture = Capture.text("An idea")
        let store = InMemoryCaptureStore(seed: [capture])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.answer(.tooManyRequests(retryAfter: 60)))
        await queue.run()
        clock.advance(by: 59)

        await queue.run()
        try await queue.resend(capture.id)
        await queue.run()

        #expect(await server.ideaRequests == 1)
        clock.advance(by: 2)
        await queue.run()
        #expect(await server.ideaRequests == 2)
    }

    @Test func aRateLimitWithoutAWaitFallsBackToTheBackoff() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.answer(.tooManyRequests(retryAfter: nil)))

        await queue.run()

        #expect(await clock.waitForSleep(number: 1) == 5)
    }

    @Test func aRateLimitedOrganizationLookupWaitsToo() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.failOrganizations(.answer(.tooManyRequests(retryAfter: 30)))

        await queue.run()

        #expect(await clock.waitForSleep(number: 1) == 30)
        #expect(await store.all().map(\.status) == [.pending])
    }

    // MARK: - Duplicates

    /// The accepted cost of not losing ideas, pinned so changing it is a decision: a lost response means a second idea.
    @Test func aLostResponseIsRetriedAndCanCreateADuplicate() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(.responseLost)

        await queue.run()
        #expect(await store.all().map(\.status) == [.pending])
        await queue.run()

        #expect(await server.ideaTexts == ["An idea", "An idea"])
        #expect(await store.all().map(\.status) == [.submitted])
    }

    /// The limit on the worst case: a server that creates the idea and then answers 500 every time.
    @Test func serverFailuresEndInFailedInsteadOfGoingOnForever() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        for _ in 0..<10 {
            await server.failIdeas(.answerAfterWork(.serverError))
        }

        for _ in 0..<10 {
            await queue.run()
        }

        #expect(await server.ideas.count == SubmissionQueue.maxServerFailures)
        #expect(await store.all().map(\.status) == [.failed])
        #expect(await store.all().map(\.failure) == [.serverTrouble])
    }

    /// Tapping Resend asks for a fresh set of tries.
    @Test func resendStartsTheServerFailureCountAgain() async throws {
        let capture = Capture.text("An idea")
        let store = InMemoryCaptureStore(seed: [capture])
        let queue = fixture.makeQueue(store: store)
        await server.failIdeas(
            .answer(.serverError), .answer(.serverError), .answer(.serverError), .answer(.serverError))
        for _ in 0..<4 {
            await queue.run()
        }

        try await queue.resend(capture.id)
        await waitUntil { await store.all().map(\.status) == [.submitted] }

        #expect(await server.ideaTexts == ["An idea"])
    }

    /// Sending it again here wouldn't be a possible duplicate but a certain one.
    @Test func aFailedSaveAfterASendDoesntSendAgain() async {
        let store = FlakyStatusCaptureStore(seed: [.text("An idea")])
        let queue = fixture.makeQueue(store: store)
        await store.failStatusWrites(true)

        await queue.run()
        await queue.run()
        #expect(await server.ideaRequests == 1)
        #expect(await store.base.all().map(\.status) == [.pending])

        await store.failStatusWrites(false)
        await queue.run()

        #expect(await server.ideaRequests == 1)
        #expect(await store.base.all().map(\.status) == [.submitted])
    }

    private func waitUntil(_ condition: @Sendable () async -> Bool) async {
        while await !condition() {
            await Task.yield()
        }
    }
}
