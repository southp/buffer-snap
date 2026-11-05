import BufferSnapCore
import SwiftUI

/// The capture list's container: owns `CaptureListModel`, loads it on appearing, on returning to the foreground and
/// when a send changes something, forwards deletes and resends to it, and passes sign-out up to whoever owns the
/// session.
/// Everything it shows is drawn by the stateless `CaptureListView`.
struct CaptureListScreen: View {
    @State private var model: CaptureListModel
    @Environment(\.scenePhase) private var scenePhase

    private let onSignOut: () -> Void

    init(store: any CaptureStore, submissions: SubmissionQueue, onSignOut: @escaping () -> Void) {
        _model = State(initialValue: CaptureListModel(store: store, submissions: submissions))
        self.onSignOut = onSignOut
    }

    var body: some View {
        // Re-render every minute so "5 minutes ago" keeps up with the clock. Not `.everyMinute`: its entries are
        // dated on the minute boundary, up to 59 seconds behind the clock, so "5 minutes ago" would read "4".
        TimelineView(.periodic(from: .now, by: 60)) { context in
            CaptureListView(
                captures: model.captures,
                now: context.date,
                onDelete: { capture in
                    Task {
                        await model.delete(capture)
                    }
                },
                onResend: { capture in
                    Task {
                        await model.resend(capture)
                    }
                },
                onSignOut: onSignOut
            )
        }
        .task {
            await model.loadAndFollowChanges()
        }
        // The widget writes to the store while the app is in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await model.load()
                }
            }
        }
    }
}
