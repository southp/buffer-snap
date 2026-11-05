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
    /// The five sample captures: every kind and every status, newest first.
    @Test func seeded() {
        assertScreenSnapshot(of: listScreen(Capture.samples()), named: "fiveSamples")
    }

    /// No captures: the empty state that points to the widget.
    @Test func empty() {
        assertScreenSnapshot(of: listScreen([]), named: "noCaptures")
    }

    private func listScreen(_ captures: [Capture]) -> some View {
        NavigationStack {
            CaptureListView(captures: captures, now: Capture.samplesReferenceDate, onDelete: { _ in })
        }
    }
}
