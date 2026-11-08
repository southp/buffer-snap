import BufferSnapCore
import SwiftUI
import Testing

@testable import BufferSnap

/// The capture list, rendered full-screen to AppTests/__Snapshots__/CaptureListViewTests/.
///
/// Wrapped in a `NavigationStack`, as `CaptureListScreen` shows it, so the title renders. Timestamps count from
/// `Capture.samplesReferenceDate`, the same "now" the samples are dated against.
@MainActor
struct CaptureListViewTests {
    /// The five sample captures: every kind and every status, newest first, with Resend on the failed one.
    @Test func seeded() {
        assertScreenSnapshot(of: listScreen(Capture.samples()), named: "fiveSamples")
    }

    /// No captures: the empty state.
    @Test func empty() {
        assertScreenSnapshot(of: listScreen([]), named: "noCaptures")
    }

    /// An open batch showing when it goes, with "Send now", above one that failed and one that was sent.
    @Test func batches() {
        let now = Capture.samplesReferenceDate
        func capture(_ text: String, minutesAgo: TimeInterval, status: Capture.Status, batch: UUID?) -> Capture {
            Capture(
                kind: .text,
                createdAt: now.addingTimeInterval(-minutesAgo * 60),
                status: status,
                text: text,
                batchID: batch
            )
        }
        let failed = UUID()
        let sent = UUID()
        let captures = [
            capture("Friday's post", minutesAgo: 3, status: .pending, batch: nil),
            capture("Add a photo of the team", minutesAgo: 1, status: .pending, batch: nil),
            capture("Newsletter intro", minutesAgo: 90, status: .failed, batch: failed),
            capture("Link to the launch", minutesAgo: 88, status: .failed, batch: failed),
            capture("Thread hook idea", minutesAgo: 600, status: .submitted, batch: sent),
            capture("A second angle on it", minutesAgo: 598, status: .submitted, batch: sent),
        ]
        assertScreenSnapshot(of: listScreen(captures), named: "openFailedAndSent")
    }

    /// Its window has ended, or it's closed: it goes when it can, with nothing left to tap.
    @Test func waitingToSend() {
        let closed = Capture(
            kind: .text,
            createdAt: Capture.samplesReferenceDate.addingTimeInterval(-60),
            text: "Sent as soon as there's a connection",
            batchID: UUID()
        )
        assertScreenSnapshot(of: listScreen([closed]), named: "closedBatch")
    }

    /// Each reason a batch didn't go, and what the header says would help: a refused batch of several captures, a
    /// refused single one, one Buffer kept failing on, and one held at sign-in. `seeded` shows one with no reason.
    @Test func failureReasons() {
        let now = Capture.samplesReferenceDate
        func failed(_ texts: [String], hoursAgo: TimeInterval, failure: Capture.Failure?) -> [Capture] {
            let batch = UUID()
            return texts.enumerated().map { index, text in
                Capture(
                    kind: .text,
                    createdAt: now.addingTimeInterval(-hoursAgo * 3600 + Double(index) * 60),
                    status: .failed,
                    text: text,
                    batchID: batch,
                    failure: failure
                )
            }
        }
        let captures =
            failed(["Launch recap", "Quote from the team", "Next steps"], hoursAgo: 1, failure: .refused)
            + failed(["Poll idea"], hoursAgo: 2, failure: .refused)
            + failed(["Behind the scenes"], hoursAgo: 3, failure: .serverTrouble)
            + failed(["Someone else's idea"], hoursAgo: 4, failure: .heldAtSignIn)
        assertScreenSnapshot(of: listScreen(captures), named: "failureReasons")
    }

    /// A long dictation shows in full, so it can be checked before it reaches Buffer.
    @Test func longCapture() {
        let long = Capture(
            kind: .text,
            createdAt: Capture.samplesReferenceDate.addingTimeInterval(-60),
            text: "週五的Post要提到Buffer的新功能: the Ideas board now takes ideas straight from your phone, "
                + "so mention the Action button, the Lock Screen and how batching joins a few thoughts into one idea."
        )
        assertScreenSnapshot(of: listScreen([long]), named: "longCapture")
    }

    // MARK: - Sync status

    @Test func allSent() {
        let sent = Capture(
            kind: .text,
            createdAt: Capture.samplesReferenceDate.addingTimeInterval(-600),
            status: .submitted,
            text: "Thread hook idea",
            batchID: UUID()
        )
        assertScreenSnapshot(of: listScreen([sent]), named: "allSent")
    }

    /// The last try couldn't reach Buffer: it goes once there's a connection, so Sync now stays.
    @Test func offline() {
        assertScreenSnapshot(of: listScreen(waitingCaptures, isOffline: true), named: "offline")
    }

    @Test func syncing() {
        assertScreenSnapshot(of: listScreen(waitingCaptures, isSyncing: true), named: "syncing")
    }

    /// A store that couldn't be written shows under the status, instead of nothing happening.
    @Test func couldNotDelete() {
        assertScreenSnapshot(of: listScreen(waitingCaptures, problem: .couldNotDelete), named: "couldNotDelete")
    }

    private var waitingCaptures: [Capture] {
        ["Friday's post", "Add a photo of the team"].enumerated().map { index, text in
            Capture(
                kind: .text,
                createdAt: Capture.samplesReferenceDate.addingTimeInterval(Double(index - 20) * 60),
                text: text,
                batchID: UUID()
            )
        }
    }

    private func listScreen(
        _ captures: [Capture],
        isOffline: Bool = false,
        isSyncing: Bool = false,
        problem: CaptureListModel.Problem? = nil
    ) -> some View {
        let batches = Array(CaptureBatch.batches(of: captures, window: 5 * 60).reversed())
        let now = Capture.samplesReferenceDate
        return NavigationStack {
            CaptureListView(
                batches: batches,
                now: now,
                syncStatus: SyncStatus(batches: batches, isOffline: isOffline, now: now),
                isSyncing: isSyncing,
                problem: problem,
                onSyncNow: {},
                onDelete: { _ in },
                onSendNow: {},
                onResend: { _ in },
                onShowBatchingSettings: {},
                onSignOut: {}
            )
        }
    }
}
