import BufferSnapCore
import Foundation
import Testing

/// How the queue sends batches: the window, and each capture ending up in exactly one idea.
struct SubmissionQueueBatchingTests {
    private let fixture = QueueFixture()
    private var server: FakeIdeasServer {
        fixture.server
    }
    private var clock: ManualSubmissionClock {
        fixture.clock
    }

    private func makeQueue(store: any CaptureStore) -> SubmissionQueue {
        fixture.makeQueue(store: store, window: 300)
    }

    // MARK: - The window

    @Test func threeCapturesInTheWindowBecomeOneIdeaInOrderWhenItEnds() async throws {
        let store = InMemoryCaptureStore()
        let queue = makeQueue(store: store)

        for text in ["First", "Second", "Third"] {
            try await store.add(fixture.capture(text))
            await queue.run()
            clock.advance(by: 100)
        }
        #expect(await server.ideaRequests == 0)
        #expect(await store.all().map(\.status) == [.pending, .pending, .pending])

        #expect(await clock.waitForSleep(number: 3) == 300)
        clock.finishLatestSleep()
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["First\n\nSecond\n\nThird"])
        await fixture.waitForStatuses(store, [.submitted, .submitted, .submitted])
    }

    /// Waiting costs nothing: no token and no request until there's something to send. Asking for a token here would
    /// lose the session, which schedules no wake-up.
    @Test func anOpenBatchMakesNoRequests() async {
        let store = InMemoryCaptureStore(seed: [fixture.capture("An idea")])
        let auth = StubAuthService(hasSavedSession: true, tokenError: AuthError.sessionExpired)
        let queue = fixture.makeQueue(store: store, auth: auth, window: 300)

        await queue.run()

        #expect(await clock.waitForSleep(number: 1) == 300)
        #expect(await server.organizationRequests == 0)
        #expect(await store.all().map(\.status) == [.pending])
    }

    @Test func aLaterCapturePushesTheWakeUpBack() async throws {
        let store = InMemoryCaptureStore(seed: [fixture.capture("First")])
        let queue = makeQueue(store: store)
        await queue.run()
        #expect(await clock.waitForSleep(number: 1) == 300)

        clock.advance(by: 200)
        try await store.add(fixture.capture("Second"))
        await queue.run()

        #expect(await clock.waitForSleep(number: 2) == 300)
        clock.finishLatestSleep()
        await fixture.waitForIdeas(1)
        #expect(await server.ideaTexts == ["First\n\nSecond"])
    }

    @Test func aCaptureAfterTheWindowStartsANewIdea() async throws {
        let store = InMemoryCaptureStore(seed: [fixture.capture("First")])
        let queue = makeQueue(store: store)
        await queue.run()
        _ = await clock.waitForSleep(number: 1)
        clock.finishLatestSleep()
        await fixture.waitForStatuses(store, [.submitted])

        try await store.add(fixture.capture("Second"))
        await queue.run()
        #expect(await server.ideaTexts == ["First"])
        _ = await clock.waitForSleep(number: 2)
        clock.finishLatestSleep()
        await fixture.waitForIdeas(2)

        #expect(await server.ideaTexts == ["First", "Second"])
    }

    /// The app wasn't running when the window ended, as with force-quitting: the first run after that sends it.
    @Test func aBatchWhoseWindowEndedWhileTheAppWasAwayGoesOnTheNextRun() async {
        let store = InMemoryCaptureStore(seed: [
            fixture.capture("First", ago: 500), fixture.capture("Second", ago: 400),
        ])
        let queue = makeQueue(store: store)

        await queue.run()

        #expect(await server.ideaTexts == ["First\n\nSecond"])
    }

    /// A relaunch has nothing to pick up but what's in the store, and the wait comes out the same.
    @Test func aRelaunchMidWindowWaitsOutWhatsLeftOfIt() async {
        let store = InMemoryCaptureStore(seed: [
            fixture.capture("First", ago: 200), fixture.capture("Second", ago: 100),
        ])
        // Its own clock, as the process it stands for is gone, and its wake-up with it.
        let beforeTheQuit = QueueFixture()
        await beforeTheQuit.makeQueue(store: store, window: 300).run()
        #expect(await beforeTheQuit.clock.waitForSleep(number: 1) == 200)

        await makeQueue(store: store).run()
        #expect(await clock.waitForSleep(number: 1) == 200)
        clock.finishLatestSleep()
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["First\n\nSecond"])
    }

    // MARK: - Exactly one idea per capture

    /// It's too late to join what's on its way, so it starts the next one, and isn't sent twice or dropped.
    @Test func aCaptureSavedMidSendGoesInTheNextIdea() async throws {
        let store = InMemoryCaptureStore(seed: [fixture.capture("First", ago: 400)])
        let queue = makeQueue(store: store)
        await server.holdNextIdea()

        async let run: Void = queue.run()
        await server.waitForHeldIdea()
        try await store.add(fixture.capture("Second"))
        await server.releaseIdea()
        await run
        #expect(await server.ideaTexts == ["First"])

        _ = await clock.waitForSleep(number: 1)
        clock.finishLatestSleep()
        await fixture.waitForIdeas(2)
        #expect(await server.ideaTexts == ["First", "Second"])
    }

    /// A lost response may mean Buffer has it: what's sent again must be the same, not a bigger idea.
    @Test func aRetryAfterALostResponseSendsTheSameTextWithoutWhatCameLater() async throws {
        let store = InMemoryCaptureStore(seed: [fixture.capture("First", ago: 400)])
        let queue = makeQueue(store: store)
        await server.failIdeas(.responseLost)

        await queue.run()
        try await store.add(fixture.capture("Second", ago: 150))
        await queue.run()

        #expect(await server.ideaTexts == ["First", "First"])
        #expect(await store.all().filter { $0.text == "Second" }.map(\.status) == [.pending])
    }

    @Test func aCaptureSavedAfterABatchFailedStartsItsOwn() async throws {
        let store = InMemoryCaptureStore(seed: [fixture.capture("First", ago: 400)])
        let queue = makeQueue(store: store)
        await server.failIdeas(.answer(.invalidInput))
        await queue.run()
        #expect(await store.all().map(\.status) == [.failed])

        try await store.add(fixture.capture("Second"))
        await queue.run()
        _ = await clock.waitForSleep(number: 1)
        clock.finishLatestSleep()
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["Second"])
        #expect(await store.all().filter { $0.text == "First" }.map(\.status) == [.failed])
    }

    /// One batch is one `createIdea`, so it can only succeed or fail whole.
    @Test(arguments: [
        (CannedAnswer.invalidInput, Capture.Status.failed),
        (CannedAnswer(body: #"{"data":{"createIdea":{"__typename":"Idea"}}}"#), .submitted),
    ])
    func aBatchsCapturesAllEndTheSame(answer: CannedAnswer, status: Capture.Status) async {
        let store = InMemoryCaptureStore(seed: [
            fixture.capture("First", ago: 500), fixture.capture("Second", ago: 400),
        ])
        let queue = makeQueue(store: store)
        await server.failIdeas(.answer(answer))

        await queue.run()

        #expect(await store.all().map(\.status) == [status, status])
        #expect(await server.ideaRequests == 1)
    }

    /// If it can't be written that the batch has closed, it mustn't go, or a retry could send different text.
    @Test func aBatchThatCantBeClosedStaysAndGoesLater() async {
        let store = FlakyStatusCaptureStore(seed: [fixture.capture("An idea", ago: 400)])
        let queue = makeQueue(store: store)
        await store.failBatchWrites(true)

        await queue.run()
        #expect(await server.ideaRequests == 0)

        await store.failBatchWrites(false)
        await queue.run()
        #expect(await server.ideaTexts == ["An idea"])
    }

    /// Server failures count against the batch, so a server stuck on it can't fill someone's Buffer.
    @Test func serverFailuresCountOncePerAttempt() async {
        let store = InMemoryCaptureStore(seed: [
            fixture.capture("First", ago: 500), fixture.capture("Second", ago: 400),
        ])
        let queue = makeQueue(store: store)

        for _ in 0..<SubmissionQueue.maxServerFailures {
            await server.failIdeas(.answerAfterWork(.serverError))
            await queue.run()
        }

        #expect(await server.ideaRequests == SubmissionQueue.maxServerFailures)
        #expect(await store.all().map(\.status) == [.failed, .failed])
    }
}

extension QueueFixture {
    /// A pending text capture made `seconds` before the clock's current time.
    func capture(_ text: String, ago seconds: TimeInterval = 0) -> Capture {
        Capture(kind: .text, createdAt: clock.now.addingTimeInterval(-seconds), text: text)
    }

    func waitForIdeas(_ count: Int) async {
        while await server.ideas.count < count {
            await Task.yield()
        }
    }

    func waitForStatuses(_ store: InMemoryCaptureStore, _ statuses: [Capture.Status]) async {
        while await store.all().map(\.status) != statuses {
            await Task.yield()
        }
    }
}
