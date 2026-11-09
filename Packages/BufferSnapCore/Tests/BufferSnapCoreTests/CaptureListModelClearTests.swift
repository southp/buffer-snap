import BufferSnapCore
import Foundation
import Testing

/// Clear Submitted. The batching window hasn't ended on the queue's clock, so nothing waiting leaves during a test.
@MainActor
struct CaptureListModelClearTests {
    @Test func clearableIdeaCountCountsIdeasNotCaptures() async {
        let batch = UUID()
        let store = InMemoryCaptureStore(seed: [
            sent("One", batch: batch), sent("Idea", batch: batch), sent("Three captures", batch: batch),
            sent("Another idea", batch: UUID()),
            .text("Still waiting"),
        ])
        let model = makeModel(store: store)

        await model.load()

        #expect(model.clearableIdeaCount == 2)
    }

    @Test func clearRemovesEverySubmittedIdeaAndNothingElse() async {
        let waiting = Capture.text("Waiting", at: 1)
        let refused = Capture(kind: .text, status: .failed, text: "Refused", failure: .refused)
        let held = Capture(kind: .text, status: .failed, text: "Held", failure: .heldAtSignIn)
        let store = InMemoryCaptureStore(seed: [sent("Sent"), sent("Also sent"), waiting, refused, held])
        let model = makeModel(store: store)
        await model.load()

        await model.clearSubmitted()

        #expect(await store.all() == [waiting, refused, held])
        #expect(Set(model.captures.map(\.id)) == [waiting.id, refused.id, held.id])
        #expect(model.clearableIdeaCount == 0)
        #expect(model.problem == nil)
    }

    /// A batch fails or goes as a whole, but if that ever breaks, what's unsent must survive a clear: the idea isn't
    /// counted as clearable, its sent part goes, and its unsent part stays listed in the same batch with its Resend.
    @Test func aBatchWithMixedStatusesIsNotCountedAndKeepsWhatIsUnsent() async throws {
        let batch = UUID()
        let unsent = Capture(kind: .text, status: .failed, text: "Unsent", batchID: batch, failure: .refused)
        let store = InMemoryCaptureStore(seed: [sent("Sent", batch: batch), unsent])
        let model = makeModel(store: store)
        await model.load()
        #expect(model.clearableIdeaCount == 0)

        await model.clearSubmitted()

        #expect(await store.all() == [unsent])
        let remaining = try #require(model.batches.first)
        #expect(remaining.id == batch)
        #expect(remaining.state == .failed)
    }

    /// The list follows the queue's events, as it does after a delete.
    @Test func clearTellsTheListToRefresh() async {
        let store = InMemoryCaptureStore(seed: [sent("Sent")])
        let queue = SubmissionQueue(
            store: store, auth: MockAuthService(hasSavedSession: true), client: MockBufferClient())
        var events = queue.events().makeAsyncIterator()
        let model = CaptureListModel(store: store, submissions: queue)

        await model.clearSubmitted()

        #expect(await events.next() == .capturesChanged)
    }

    @Test func aFailedClearSaysSoAndLosesNothing() async {
        let capture = sent("Sent")
        let model = makeModel(store: ReadOnlyCaptureStore(captures: [capture]))
        await model.load()

        await model.clearSubmitted()

        #expect(model.problem == .couldNotClear)
        #expect(model.captures == [capture])
        #expect(model.clearableIdeaCount == 1)
    }

    private func sent(_ text: String, batch: Capture.BatchID = UUID()) -> Capture {
        Capture(kind: .text, status: .submitted, text: text, batchID: batch)
    }

    private func makeModel(store: any CaptureStore) -> CaptureListModel {
        let clock = ManualSubmissionClock()
        clock.advance(by: Date(timeIntervalSinceReferenceDate: 10).timeIntervalSince(clock.now))
        return CaptureListModel(
            store: store,
            submissions: SubmissionQueue(
                store: store,
                auth: MockAuthService(hasSavedSession: true),
                client: MockBufferClient(),
                planner: SubmissionPlanner { 300 },
                clock: clock
            )
        )
    }
}
