import BufferSnapCore
import Foundation
import Testing

/// What people can do to a batch: send it now, resend it, delete from it, and what a sign-in does to it.
struct SubmissionQueueBatchActionTests {
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

    // MARK: - Send now

    @Test func sendNowSendsTheOpenBatchAtOnceAsOneIdea() async throws {
        let store = InMemoryCaptureStore(seed: [fixture.capture("First", ago: 10), fixture.capture("Second")])
        let queue = makeQueue(store: store)
        await queue.run()
        #expect(await server.ideaRequests == 0)

        try await queue.sendNow()
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["First\n\nSecond"])
        await fixture.waitForStatuses(store, [.submitted, .submitted])
    }

    /// The batch was closed by the tap, and stays what it was then.
    @Test func aCaptureSavedAfterSendNowStartsANewIdeaEvenIfTheSendHasntHappened() async throws {
        let store = InMemoryCaptureStore(seed: [fixture.capture("First")])
        let queue = makeQueue(store: store)
        await server.failIdeas(.offline)
        try await queue.sendNow()
        _ = await clock.waitForSleep(number: 1)

        try await store.add(fixture.capture("Second"))
        await queue.run()

        #expect(await server.ideaTexts == ["First"])
        #expect(await store.all().filter { $0.text == "Second" }.map(\.batchID) == [nil])
    }

    /// "Send now" was tapped, and then the app was force-quit before anything could leave.
    @Test func aRelaunchAfterSendNowDoesntWaitForTheWindow() async throws {
        let store = InMemoryCaptureStore(seed: [fixture.capture("First")])
        let queue = makeQueue(store: store)
        await server.failIdeas(.offline)
        try await queue.sendNow()
        _ = await clock.waitForSleep(number: 1)

        await makeQueue(store: store).run()

        #expect(await server.ideaTexts == ["First"])
    }

    /// The tap still counts, and it goes as soon as Buffer allows.
    @Test func sendNowDuringARateLimitGoesWhenItEnds() async throws {
        let store = InMemoryCaptureStore(seed: [fixture.capture("First", ago: 400), fixture.capture("Second")])
        let queue = makeQueue(store: store)
        await server.failIdeas(.answer(.tooManyRequests(retryAfter: 30)))
        await queue.run()

        try await queue.sendNow()
        #expect(await server.ideaRequests == 1)

        _ = await clock.waitForSleep(number: 1)
        clock.finishLatestSleep()
        await fixture.waitForIdeas(2)
        #expect(await server.ideaTexts == ["First", "Second"])
    }

    @Test func sendNowWithNothingOpenMakesNoRequests() async throws {
        let queue = makeQueue(store: InMemoryCaptureStore())

        try await queue.sendNow()
        await queue.run()

        #expect(await server.organizationRequests == 0)
    }

    // MARK: - Resend

    @Test func resendSendsAFailedBatchAsOneIdeaWithoutWaiting() async throws {
        let first = fixture.capture("First", ago: 500)
        let store = InMemoryCaptureStore(seed: [first, fixture.capture("Second", ago: 400)])
        let queue = makeQueue(store: store)
        await server.failIdeas(.answer(.invalidInput))
        await queue.run()
        #expect(await store.all().map(\.status) == [.failed, .failed])

        try await queue.resend(first.id)
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["First\n\nSecond"])
        await fixture.waitForStatuses(store, [.submitted, .submitted])
    }

    /// It may be newer than what failed, and they were never one idea.
    @Test func aResentBatchDoesntMergeWithWhatsOpen() async throws {
        let failed = fixture.capture("Failed", ago: 400)
        let store = InMemoryCaptureStore(seed: [failed])
        let queue = makeQueue(store: store)
        await server.failIdeas(.answer(.invalidInput))
        await queue.run()
        try await store.add(fixture.capture("Open"))

        try await queue.resend(failed.id)
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["Failed"])
        await fixture.waitForStatuses(store, [.submitted, .pending])
    }

    /// From before batches. Two of these resent together must stay two ideas, whatever their timestamps say.
    @Test func resendingACaptureFromBeforeBatchesSendsOnlyThatOne() async throws {
        let older = Capture(kind: .text, createdAt: clock.now, status: .failed, text: "Older")
        let newer = Capture(kind: .text, createdAt: clock.now, status: .failed, text: "Newer")
        let store = InMemoryCaptureStore(seed: [older, newer])
        let queue = makeQueue(store: store)

        try await queue.resend(older.id)
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["Older"])
        await fixture.waitForStatuses(store, [.submitted, .failed])
    }

    /// A second tap, or a tap on a row out of date, mustn't send something that already went.
    @Test func resendingABatchThatDidntFailDoesNothing() async throws {
        let sent = fixture.capture("Sent", ago: 400)
        let store = InMemoryCaptureStore(seed: [sent])
        let queue = makeQueue(store: store)
        await queue.run()

        try await queue.resend(sent.id)
        await queue.run()

        #expect(await server.ideaRequests == 1)
    }

    /// Restarting the count is part of what Resend means, for every capture in the batch.
    @Test func resendStartsTheBatchsServerFailureCountAgain() async throws {
        let first = fixture.capture("First", ago: 500)
        let store = InMemoryCaptureStore(seed: [first, fixture.capture("Second", ago: 400)])
        let queue = makeQueue(store: store)
        for _ in 0..<SubmissionQueue.maxServerFailures {
            await server.failIdeas(.answerAfterWork(.serverError))
            await queue.run()
        }
        #expect(await store.all().map(\.status) == [.failed, .failed])

        await server.failIdeas(.answerAfterWork(.serverError))
        try await queue.resend(first.id)
        await queue.run()

        #expect(await store.all().map(\.status) == [.pending, .pending])
    }

    // MARK: - Delete

    @Test func aCaptureDeletedFromAnOpenBatchIsLeftOutOfTheIdea() async throws {
        let doomed = fixture.capture("Doomed", ago: 100)
        let store = InMemoryCaptureStore(seed: [fixture.capture("First", ago: 200), doomed, fixture.capture("Last")])
        let queue = makeQueue(store: store)
        await queue.run()

        await store.delete(id: doomed.id)
        await queue.replan()
        try await queue.sendNow()
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["First\n\nLast"])
    }

    /// The last capture set the time, so the batch may be due the moment it's gone.
    @Test func deletingTheLastCaptureBringsTheBatchForward() async {
        let last = fixture.capture("Last")
        let store = InMemoryCaptureStore(seed: [fixture.capture("First", ago: 290), last])
        let queue = makeQueue(store: store)
        await queue.run()
        #expect(await server.ideaRequests == 0)
        clock.advance(by: 20)

        await store.delete(id: last.id)
        await queue.replan()
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["First"])
    }

    @Test func aCaptureDeletedFromAFailedBatchIsLeftOutOfTheResend() async throws {
        let first = fixture.capture("First", ago: 500)
        let doomed = fixture.capture("Doomed", ago: 400)
        let store = InMemoryCaptureStore(seed: [first, doomed])
        let queue = makeQueue(store: store)
        await server.failIdeas(.answer(.invalidInput))
        await queue.run()

        await store.delete(id: doomed.id)
        try await queue.resend(first.id)
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["First"])
    }

    /// The batch is named after its first capture, which may be the one that's gone.
    @Test func deletingTheFirstCaptureLeavesTheBatchResendable() async throws {
        let doomed = fixture.capture("Doomed", ago: 500)
        let store = InMemoryCaptureStore(seed: [doomed, fixture.capture("Second", ago: 400)])
        let queue = makeQueue(store: store)
        await server.failIdeas(.answer(.invalidInput))
        await queue.run()

        await store.delete(id: doomed.id)
        try await queue.resend(doomed.id)
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["Second"])
    }

    @Test func deletingFromABatchWaitingForAConnectionChangesWhatGoes() async {
        let doomed = fixture.capture("Doomed", ago: 400)
        let store = InMemoryCaptureStore(seed: [fixture.capture("First", ago: 500), doomed])
        let queue = makeQueue(store: store)
        await server.failIdeas(.offline)
        await queue.run()

        await store.delete(id: doomed.id)
        await queue.run()

        #expect(await server.ideaTexts == ["First"])
    }

    // MARK: - Holding for a sign-in

    /// All of it went before the sign-in, and whichever account is next must not get it by itself.
    @Test func aHeldBatchStaysTogetherAndGoesOnlyOnResend() async throws {
        let first = fixture.capture("First", ago: 100)
        let store = InMemoryCaptureStore(seed: [first, fixture.capture("Second")])
        let queue = makeQueue(store: store)

        try await queue.holdPendingCaptures()
        #expect(await store.all().map(\.status) == [.failed, .failed])
        #expect(await store.all().map(\.batchID) == [first.id, first.id])

        clock.advance(by: 1000)
        await queue.run()
        #expect(await server.ideaRequests == 0)

        try await queue.resend(first.id)
        await fixture.waitForIdeas(1)
        #expect(await server.ideaTexts == ["First\n\nSecond"])
    }

    @Test func aCaptureSavedAfterAHoldDoesntJoinWhatWasHeld() async throws {
        let store = InMemoryCaptureStore(seed: [fixture.capture("Held", ago: 10)])
        let queue = makeQueue(store: store)
        try await queue.holdPendingCaptures()

        try await store.add(fixture.capture("New"))
        try await queue.sendNow()
        await fixture.waitForIdeas(1)

        #expect(await server.ideaTexts == ["New"])
        #expect(await store.all().filter { $0.text == "Held" }.map(\.status) == [.failed])
    }

    /// Two batches held at once mustn't merge just because they failed together.
    @Test func batchesHeldTogetherStaySeparate() async throws {
        let first = fixture.capture("First", ago: 1000)
        let second = fixture.capture("Second")
        let store = InMemoryCaptureStore(seed: [first, second])
        let queue = makeQueue(store: store)

        try await queue.holdPendingCaptures()

        #expect(await store.all().map(\.batchID) == [first.id, second.id])
    }
}
