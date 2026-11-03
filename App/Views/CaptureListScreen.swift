import BufferSnapCore
import SwiftUI

/// The capture list's container: owns `CaptureListModel`, loads it on appearing and on returning to the foreground,
/// and forwards deletes to it.
/// Everything it shows is drawn by the stateless `CaptureListView`.
struct CaptureListScreen: View {
    @State private var model: CaptureListModel
    @Environment(\.scenePhase) private var scenePhase

    init(store: any CaptureStore) {
        _model = State(initialValue: CaptureListModel(store: store))
    }

    var body: some View {
        NavigationStack {
            // Re-render every minute so "5 minutes ago" keeps up with the clock. Not `.everyMinute`: its entries are
            // dated on the minute boundary, up to 59 seconds behind the clock, so "5 minutes ago" would read "4".
            TimelineView(.periodic(from: .now, by: 60)) { context in
                CaptureListView(captures: model.captures, now: context.date) { capture in
                    Task {
                        await model.delete(capture)
                    }
                }
            }
        }
        .task {
            await model.load()
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
