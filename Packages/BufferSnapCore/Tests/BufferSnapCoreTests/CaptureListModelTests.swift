import BufferSnapCore
import Foundation
import Testing

@MainActor
struct CaptureListModelTests {
    @Test func startsEmpty() {
        let model = makeModel(store: InMemoryCaptureStore(seed: [.at(1)]))

        #expect(model.captures.isEmpty)
    }

    @Test func loadSortsNewestFirst() async {
        let oldest = Capture.at(1)
        let middle = Capture.at(2, kind: .photo)
        let newest = Capture.at(3, kind: .photo)
        let model = makeModel(store: InMemoryCaptureStore(seed: [middle, newest, oldest]))

        await model.load()

        #expect(model.captures == [newest, middle, oldest])
    }

    @Test func deleteRemovesFromListAndStore() async {
        let older = Capture.at(1)
        let newer = Capture.at(2)
        let store = InMemoryCaptureStore(seed: [older, newer])
        let model = makeModel(store: store)
        await model.load()

        await model.delete(older)

        #expect(model.captures == [newer])
        #expect(await store.all() == [newer])

        // The store is the source of truth: a reload must not bring the capture back.
        await model.load()
        #expect(model.captures == [newer])
    }

    @Test func failedDeleteKeepsCapture() async {
        let capture = Capture.at(1)
        let model = makeModel(store: ReadOnlyCaptureStore(captures: [capture]))
        await model.load()

        await model.delete(capture)

        #expect(model.captures == [capture])
    }

    @Test func resendMakesAFailedCapturePendingAndSendsIt() async throws {
        let capture = Capture.text("An idea")
        let store = InMemoryCaptureStore(seed: [capture])
        try await store.setStatus(.failed, ids: [capture.id])
        let buffer = MockBufferClient()
        let model = makeModel(store: store, buffer: buffer)
        await model.load()
        #expect(model.captures.map(\.status) == [.failed])

        await model.resend(try #require(model.batches.first))

        while await buffer.createdIdeas.isEmpty {
            await Task.yield()
        }
        #expect(await buffer.createdIdeas == ["An idea"])
    }

    /// The row mustn't still say "Failed" with its button after the tap.
    @Test func resendShowsTheNewStatusAtOnce() async throws {
        let capture = Capture.text("An idea")
        let store = InMemoryCaptureStore(seed: [capture])
        try await store.setStatus(.failed, ids: [capture.id])
        let model = makeModel(store: store)
        await model.load()

        await model.resend(try #require(model.batches.first))

        #expect(model.captures.map(\.status) != [.failed])
    }

    @Test func aFailedResendLeavesItFailed() async throws {
        let capture = Capture(kind: .text, status: .failed, text: "An idea")
        let model = makeModel(store: ReadOnlyCaptureStore(captures: [capture]))
        await model.load()

        await model.resend(try #require(model.batches.first))

        #expect(model.captures == [capture])
    }

    /// A send finishing while the list is open shows without leaving and coming back.
    @Test func theListFollowsSendsWhileItsOpen() async {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let auth = MockAuthService(hasSavedSession: true)
        let queue = SubmissionQueue(store: store, auth: auth, client: MockBufferClient())
        let model = CaptureListModel(store: store, submissions: queue)

        let following = Task {
            await model.loadAndFollowChanges()
        }
        while model.captures.isEmpty {
            await Task.yield()
        }
        await queue.run()
        while model.captures.map(\.status) != [.submitted] {
            await Task.yield()
        }
        following.cancel()
    }

    // MARK: - Batches

    @Test func batchesAreNewestFirstWithCapturesInTheOrderMade() async {
        let older = [Capture.text("A", at: 0), .text("B", at: 100)]
        let newer = Capture.text("C", at: 1000)
        let model = makeModel(store: InMemoryCaptureStore(seed: older + [newer]), window: 300)

        await model.load()

        #expect(model.batches.map { $0.captures.map(\.text) } == [["C"], ["A", "B"]])
    }

    @Test func deletingACaptureUpdatesItsBatch() async {
        let doomed = Capture.text("B", at: 100)
        let store = InMemoryCaptureStore(seed: [.text("A", at: 0), doomed])
        let model = makeModel(store: store, window: 300, planWithClockAt: Date(timeIntervalSinceReferenceDate: 100))
        await model.load()

        await model.delete(doomed)

        #expect(model.batches.map { $0.captures.map(\.text) } == [["A"]])
    }

    /// Deleting the one that set the time can make the batch due, and it mustn't wait for something else to notice.
    @Test func deletingACaptureMakesTheQueuePlanAgain() async {
        let doomed = Capture.text("B", at: 100)
        let store = InMemoryCaptureStore(seed: [.text("A", at: 0), doomed])
        let buffer = MockBufferClient()
        let model = makeModel(
            store: store,
            buffer: buffer,
            window: 300,
            planWithClockAt: Date(timeIntervalSinceReferenceDate: 350)
        )
        await model.load()

        await model.delete(doomed)

        while await buffer.createdIdeas.isEmpty {
            await Task.yield()
        }
        #expect(await buffer.createdIdeas == ["A"])
    }

    @Test func sendNowSendsTheOpenBatch() async throws {
        let store = InMemoryCaptureStore(seed: [.text("A", at: 0), .text("B", at: 100)])
        let buffer = MockBufferClient()
        let model = makeModel(
            store: store,
            buffer: buffer,
            window: 300,
            planWithClockAt: Date(timeIntervalSinceReferenceDate: 100)
        )
        await model.load()
        #expect(model.batches.count == 1)

        await model.sendNow()

        while await buffer.createdIdeas.isEmpty {
            await Task.yield()
        }
        #expect(await buffer.createdIdeas == ["A\n\nB"])
        #expect(model.batches.first?.isWaiting(at: Date(timeIntervalSinceReferenceDate: 100)) == false)
    }

    @Test func aFailedSendNowKeepsTheList() async {
        let capture = Capture.text("A", at: 0)
        let model = makeModel(store: ReadOnlyCaptureStore(captures: [capture]), window: 300)
        await model.load()

        await model.sendNow()

        #expect(model.captures == [capture])
    }

    /// A batch that failed offers one Resend, which takes all of it.
    @Test func resendingAFailedBatchSendsAllOfItAsOneIdea() async throws {
        let batchID = UUID()
        let captures = ["A", "B"].enumerated().map { index, text in
            Capture(
                kind: .text,
                createdAt: Date(timeIntervalSinceReferenceDate: Double(index)),
                status: .failed,
                text: text,
                batchID: batchID
            )
        }
        let buffer = MockBufferClient()
        let model = makeModel(store: InMemoryCaptureStore(seed: captures), buffer: buffer, window: 300)
        await model.load()

        await model.resend(try #require(model.batches.first))

        while await buffer.createdIdeas.isEmpty {
            await Task.yield()
        }
        #expect(await buffer.createdIdeas == ["A\n\nB"])
    }

    private func makeModel(
        store: any CaptureStore,
        buffer: MockBufferClient = MockBufferClient(),
        window: TimeInterval = 0,
        planWithClockAt now: Date? = nil
    ) -> CaptureListModel {
        let auth = MockAuthService(hasSavedSession: true)
        let clock = ManualSubmissionClock()
        if let now {
            clock.advance(by: now.timeIntervalSince(clock.now))
        }
        return CaptureListModel(
            store: store,
            submissions: SubmissionQueue(
                store: store,
                auth: auth,
                client: buffer,
                planner: SubmissionPlanner { window },
                clock: now == nil ? SystemSubmissionClock() : clock
            )
        )
    }
}
