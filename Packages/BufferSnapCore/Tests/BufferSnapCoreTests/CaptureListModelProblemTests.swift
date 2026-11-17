import BufferSnapCore
import Foundation
import Testing

/// What the list says when the store can't be read or written, and when it stops saying it.
@MainActor
struct CaptureListModelProblemTests {
    @Test func anUnreadableStoreKeepsTheListAndSaysSo() async {
        let model = makeModel(store: UnreadableCaptureStore())

        await model.load()

        #expect(model.captures.isEmpty)
        #expect(model.problem == .couldNotLoad)
    }

    @Test func aFailedDeleteSaysSo() async {
        let capture = Capture.at(1)
        let model = makeModel(store: ReadOnlyCaptureStore(captures: [capture]))
        await model.load()

        await model.delete(capture)

        #expect(model.problem == .couldNotDelete)
    }

    @Test func aFailedResendSaysSo() async throws {
        let capture = Capture(kind: .text, status: .failed, text: "An idea")
        let model = makeModel(store: ReadOnlyCaptureStore(captures: [capture]))
        await model.load()

        await model.resend(try #require(model.batches.first))

        #expect(model.problem == .couldNotResend)
    }

    @Test func aFailedSyncSaysSoAndTheNextOneClearsIt() async {
        let store = FlakyStatusCaptureStore(seed: [.text("A", at: 0)])
        await store.failBatchWrites(true)
        let model = makeModel(store: store, window: 300, planWithClockAt: Date(timeIntervalSinceReferenceDate: 10))
        await model.load()

        await model.syncNow()
        #expect(model.problem == .couldNotSend)

        await store.failBatchWrites(false)
        await model.syncNow()
        #expect(model.problem == nil)
    }

    /// A delete says nothing about whether the store can be read, so the list still says it may be out of date.
    @Test func aFailedLoadStillShowsAfterADeleteWorks() async {
        let capture = Capture.at(1)
        let store = SwitchableCaptureStore(seed: [capture])
        let model = makeModel(store: store)
        await model.load()
        await store.failReads(true)
        await model.load()
        #expect(model.problem == .couldNotLoad)

        await model.delete(capture)

        #expect(model.problem == .couldNotLoad)
    }

    /// The capture that couldn't be deleted is still there, whatever a sync does.
    @Test func aFailedDeleteStillShowsAfterASyncWorks() async {
        let capture = Capture.at(1)
        let store = SwitchableCaptureStore(seed: [capture])
        await store.failDeletes(true)
        let model = makeModel(store: store)
        await model.load()
        await model.delete(capture)
        #expect(model.problem == .couldNotDelete)

        await model.syncNow()

        #expect(model.problem == .couldNotDelete)
    }

    @Test func aDeleteThatWorksClearsAFailedDelete() async {
        let capture = Capture.at(1)
        let store = SwitchableCaptureStore(seed: [capture])
        await store.failDeletes(true)
        let model = makeModel(store: store)
        await model.load()
        await model.delete(capture)
        #expect(model.problem == .couldNotDelete)

        await store.failDeletes(false)
        await model.delete(capture)

        #expect(model.problem == nil)
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
