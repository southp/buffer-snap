import BufferSnapCore
import Foundation
import Testing

struct SubmissionPlannerTests {
    private let planner = SubmissionPlanner { 300 }

    private func at(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: seconds)
    }

    @Test func nothingPendingMeansNothingToDo() {
        #expect(planner.plan(pending: [], now: at(0)) == .nothing)
    }

    /// Timestamps are all it takes, so a relaunch mid-window lands here with the same answer.
    @Test func anOpenBatchWaitsForAWindowAfterItsLastCapture() {
        let pending = [Capture.text("A", at: 0), .text("B", at: 100)]

        #expect(planner.plan(pending: pending, now: at(150)) == .wait(until: at(400)))
    }

    @Test func aBatchGoesAsOneIdeaExactlyWhenItsWindowEnds() {
        let first = Capture.text("A", at: 0)
        let second = Capture.text("B", at: 100)

        let plan = planner.plan(pending: [second, first], now: at(400))

        #expect(
            plan
                == .send(Submission(batchID: first.id, captureIDs: [first.id, second.id], text: "A\n\nB"))
        )
    }

    @Test func aBatchStillWaitsJustBeforeItsWindowEnds() {
        #expect(planner.plan(pending: [.text("A", at: 0)], now: at(299.9)) == .wait(until: at(300)))
    }

    @Test func aClosedBatchGoesWhateverTheWindowSays() {
        let batchID = UUID()
        let captures = [Capture.text("A", at: 0, batch: batchID), .text("B", at: 1, batch: batchID)]

        let plan = planner.plan(pending: captures, now: at(2))

        #expect(plan == .send(Submission(batchID: batchID, captureIDs: captures.map(\.id), text: "A\n\nB")))
    }

    @Test func aDueBatchGoesBeforeAnOpenOne() {
        let due = Capture.text("Due", at: 0)
        let open = Capture.text("Open", at: 1000)

        let plan = planner.plan(pending: [open, due], now: at(1100))

        #expect(plan == .send(Submission(batchID: due.id, captureIDs: [due.id], text: "Due")))
    }

    /// Off: nothing waits, and each capture is its own idea.
    @Test func noBatchingSendsEachCaptureAtOnce() {
        let first = Capture.text("A", at: 0)
        let plan = SubmissionPlanner.noBatching.plan(pending: [first, .text("B", at: 1)], now: at(1))

        #expect(plan == .send(Submission(batchID: first.id, captureIDs: [first.id], text: "A")))
    }

    @Test func whatCantBecomeAnIdeaNeverPlansAnything() {
        let photo = Capture(kind: .photo, createdAt: at(0), text: "A caption")

        #expect(planner.plan(pending: [photo], now: at(1000)) == .nothing)
    }

    /// A failed resend can leave one like this: it mustn't hold up what's behind it.
    @Test func aClosedBatchWithNothingToSendIsSkipped() {
        let photo = Capture(kind: .photo, createdAt: at(0), batchID: UUID())
        let text = Capture.text("A", at: 1)

        let plan = planner.plan(pending: [photo, text], now: at(1000))

        #expect(plan == .send(Submission(batchID: text.id, captureIDs: [text.id], text: "A")))
    }
}
