import BufferSnapCore
import Foundation
import Testing

/// How captures group into batches. Timestamps are seconds after a fixed date, as in `Capture.text(_:at:)`.
struct CaptureBatchTests {
    private let window: TimeInterval = 300

    private func batches(_ captures: [Capture], window: TimeInterval? = nil) -> [[String?]] {
        CaptureBatch.batches(of: captures, window: window ?? self.window).map { $0.captures.map(\.text) }
    }

    @Test func capturesWithinTheWindowJoinInOrder() {
        let captures = [Capture.text("C", at: 200), .text("A", at: 0), .text("B", at: 100)]

        #expect(batches(captures) == [["A", "B", "C"]])
    }

    /// The list shows the newest at the top, while the idea keeps the order they were made in.
    @Test func theListShowsTheNewestFirstButTheIdeaKeepsTheirOrder() throws {
        let captures = [Capture.text("A", at: 0), .text("B", at: 100), .text("C", at: 200)]

        let batch = try #require(CaptureBatch.batches(of: captures, window: window).first)

        #expect(batch.newestFirst.map(\.text) == ["C", "B", "A"])
        #expect(batch.text == "A\n\nB\n\nC")
    }

    /// Each stays within the window of the one before, though the last is well past the window after the first.
    @Test func theWindowRestartsAfterEachCapture() {
        let captures = [Capture.text("A", at: 0), .text("B", at: 299), .text("C", at: 598), .text("D", at: 897)]

        #expect(batches(captures) == [["A", "B", "C", "D"]])
    }

    @Test func aCaptureJustInsideTheWindowJoins() {
        #expect(batches([.text("A", at: 0), .text("B", at: 299.999)]) == [["A", "B"]])
    }

    /// The batch is due at that very moment, so the new capture can't still join it.
    @Test func aCaptureExactlyAtTheWindowStartsANewBatch() {
        #expect(batches([.text("A", at: 0), .text("B", at: 300)]) == [["A"], ["B"]])
    }

    @Test func aCaptureAfterTheWindowStartsANewBatch() {
        #expect(batches([.text("A", at: 0), .text("B", at: 500), .text("C", at: 600)]) == [["A"], ["B", "C"]])
    }

    @Test(arguments: [0, -1] as [TimeInterval])
    func noWindowLeavesEachCaptureByItself(window: TimeInterval) {
        let captures = [Capture.text("A", at: 0), .text("B", at: 0), .text("C", at: 1)]

        #expect(batches(captures, window: window) == [["A"], ["B"], ["C"]])
    }

    @Test func anOpenBatchSendsAWindowAfterItsLastCapture() throws {
        let last = Capture.text("B", at: 100)

        let batch = try #require(CaptureBatch.batches(of: [.text("A", at: 0), last], window: window).first)

        #expect(batch.state == .open(sendsAt: last.createdAt.addingTimeInterval(window)))
    }

    /// Set, as a batch closes under this ID, and the list has to keep showing it as the same one.
    @Test func anOpenBatchIsNamedAfterItsFirstCapture() {
        let first = Capture.text("A", at: 0)

        #expect(CaptureBatch.batches(of: [first, .text("B", at: 100)], window: window).map(\.id) == [first.id])
    }

    @Test func isWaitingOnlyUntilTheWindowEnds() throws {
        let capture = Capture.text("A", at: 0)
        let batch = try #require(CaptureBatch.batches(of: [capture], window: window).first)

        #expect(batch.isWaiting(at: capture.createdAt.addingTimeInterval(299)))
        #expect(!batch.isWaiting(at: capture.createdAt.addingTimeInterval(300)))
    }

    @Test func theTextIsTheCapturesInOrderWithBlankLinesBetween() {
        let batch = CaptureBatch.batches(of: [.text("Two", at: 2), .text("One", at: 1)], window: window).first

        #expect(batch?.text == "One\n\nTwo")
    }

    // MARK: - Closed batches

    @Test func aClosedBatchIsWhatItsCapturesSay() {
        let batchID = UUID()
        let captures = [Capture.text("A", at: 0, batch: batchID), .text("B", at: 5000, batch: batchID)]

        let batch = CaptureBatch.batches(of: captures, window: window)

        #expect(batch.map(\.id) == [batchID])
        #expect(batch.map(\.state) == [.closed])
        #expect(batch.first?.text == "A\n\nB")
    }

    /// Something saved just after a batch closed goes in the next one, however close it is.
    @Test func aClosedBatchTakesNoMoreCaptures() {
        let batchID = UUID()
        let captures = [Capture.text("A", at: 0, batch: batchID), .text("B", at: 1)]

        #expect(batches(captures) == [["A"], ["B"]])
    }

    /// A closed batch between them doesn't count as a gap: only what's still open can join.
    @Test func openCapturesGroupAmongThemselves() {
        let captures = [Capture.text("A", at: 0), .text("Closed", at: 1, batch: UUID()), .text("B", at: 2)]

        #expect(batches(captures) == [["A", "B"], ["Closed"]])
    }

    @Test(arguments: [
        (Capture.Status.pending, CaptureBatch.State.closed),
        (.submitted, .submitted),
        (.failed, .failed),
    ])
    func aClosedBatchsStateComesFromItsCaptures(status: Capture.Status, state: CaptureBatch.State) {
        let batchID = UUID()
        let captures = ["A", "B"].map { Capture(kind: .text, status: status, text: $0, batchID: batchID) }

        #expect(CaptureBatch.batches(of: captures, window: window).map(\.state) == [state])
    }

    /// From before batches: nothing says they went together, and they were each their own idea.
    @Test func sentOrFailedCapturesWithNoBatchStandAlone() {
        let captures = [
            Capture(kind: .text, createdAt: .init(timeIntervalSinceReferenceDate: 0), status: .submitted, text: "A"),
            Capture(kind: .text, createdAt: .init(timeIntervalSinceReferenceDate: 1), status: .submitted, text: "B"),
            Capture(kind: .text, createdAt: .init(timeIntervalSinceReferenceDate: 2), status: .failed, text: "C"),
        ]

        let batches = CaptureBatch.batches(of: captures, window: window)

        #expect(batches.map(\.state) == [.submitted, .submitted, .failed])
        #expect(batches.map(\.id) == captures.map(\.id))
    }

    /// It stays pending and doesn't change when what's around it goes.
    @Test func whatCantBecomeAnIdeaStaysOutOfBatches() {
        let photo = Capture(kind: .photo, createdAt: .init(timeIntervalSinceReferenceDate: 1), text: "A caption")
        let mock = Capture(kind: .text, createdAt: .init(timeIntervalSinceReferenceDate: 2), text: "Mock text capture")
        let blank = Capture.text("  \n", at: 3)
        let captures = [Capture.text("A", at: 0), photo, mock, blank, .text("B", at: 4)]

        let batches = CaptureBatch.batches(of: captures, window: window)

        #expect(batches.map(\.captures.count) == [2, 1, 1, 1])
        #expect(batches.dropFirst().map(\.state) == [.unsendable, .unsendable, .unsendable])
        #expect(batches.first?.text == "A\n\nB")
    }
}
