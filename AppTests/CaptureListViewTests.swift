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

    private func listScreen(_ captures: [Capture]) -> some View {
        NavigationStack {
            CaptureListView(
                batches: CaptureBatch.batches(of: captures, window: 5 * 60).reversed(),
                now: Capture.samplesReferenceDate,
                onDelete: { _ in },
                onSendNow: {},
                onResend: { _ in },
                onShowBatchingSettings: {},
                onSignOut: {}
            )
        }
    }
}
