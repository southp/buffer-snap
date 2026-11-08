import BufferSnapCore
import Foundation
import Testing

/// The one-line answer to "did everything reach Buffer?". Timestamps are seconds after a fixed date.
struct SyncStatusTests {
    private let window: TimeInterval = 300
    private let now = Date(timeIntervalSinceReferenceDate: 100)

    private func status(_ captures: [Capture], isOffline: Bool = false) -> SyncStatus {
        SyncStatus(batches: CaptureBatch.batches(of: captures, window: window), isOffline: isOffline, now: now)
    }

    private func capture(_ status: Capture.Status, at seconds: TimeInterval = 0, batch: UUID? = nil) -> Capture {
        Capture(
            kind: .text,
            createdAt: Date(timeIntervalSinceReferenceDate: seconds),
            status: status,
            text: "An idea",
            batchID: batch
        )
    }

    @Test func noCapturesIsNothingYet() {
        #expect(status([]) == .nothingYet)
    }

    @Test func everythingSubmittedIsAllSent() {
        #expect(status([capture(.submitted, batch: UUID()), capture(.submitted, batch: UUID())]) == .allSent)
    }

    @Test func anOpenBatchSaysWhenItGoes() {
        let captures = [capture(.pending, at: 0), capture(.pending, at: 60)]

        #expect(status(captures) == .waiting(count: 2, nextSendAt: Date(timeIntervalSinceReferenceDate: 360)))
    }

    /// Closed, or its window is over: it goes as soon as it can, so there's no time to show.
    @Test func aClosedBatchWaitsWithNoTime() {
        #expect(status([capture(.pending, batch: UUID())]) == .waiting(count: 1, nextSendAt: nil))
    }

    @Test func waitingWhileOfflineIsOffline() {
        #expect(status([capture(.pending, batch: UUID())], isOffline: true) == .offline(count: 1))
    }

    /// Being offline with nothing to send isn't worth a word.
    @Test func offlineWithNothingWaitingIsAllSent() {
        #expect(status([capture(.submitted, batch: UUID())], isOffline: true) == .allSent)
    }

    /// What needs a tap comes first, and still says how many go by themselves.
    @Test func aFailureOutranksEverythingElse() {
        let failedBatch = UUID()
        let captures = [
            capture(.failed, batch: failedBatch),
            capture(.failed, batch: failedBatch),
            capture(.pending, at: 50),
            capture(.submitted, batch: UUID()),
        ]

        #expect(status(captures, isOffline: true) == .failed(count: 2, waiting: 1))
    }

    /// A picture can't go yet (`docs/decisions/10-capture-kinds.md`), so it isn't waiting for anything.
    @Test func whatCantBecomeAnIdeaIsntWaiting() {
        let photo = Capture(kind: .photo, createdAt: Date(timeIntervalSinceReferenceDate: 0))

        #expect(status([photo, capture(.submitted, batch: UUID())]) == .allSent)
        #expect(SyncStatus.waitingCount(of: [photo]) == 0)
    }

    @Test func theWaitingCountLeavesOutFailedAndSent() {
        let captures = [capture(.pending, at: 0), capture(.pending, at: 1000), capture(.failed), capture(.submitted)]

        #expect(SyncStatus.waitingCount(of: captures) == 2)
    }

    @Test(arguments: [
        (SyncStatus.nothingYet, false),
        (.allSent, false),
        (.waiting(count: 1, nextSendAt: nil), true),
        (.offline(count: 1), true),
        (.failed(count: 1, waiting: 0), false),
        (.failed(count: 1, waiting: 2), true),
    ])
    func syncNowIsOnlyOfferedWithSomethingToSend(status: SyncStatus, canSync: Bool) {
        #expect(status.canSyncNow == canSync)
    }
}
