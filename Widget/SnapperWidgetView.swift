import SwiftUI

/// The widget's face on the Home Screen and in the Today View: how many captures are waiting to send, and a button that
/// starts listening without opening the app.
struct SnapperWidgetView: View {
    /// Captures waiting to send: `docs/decisions/46-widget-counts-waiting.md`.
    let waitingCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if waitingCount > 0 {
                    Text("\(waitingCount) waiting to send")
                } else {
                    Text("Nothing waiting")
                }
            }
            .font(.headline)
            // Don't animate: with the default transition the simulator kept drawing the previous count until the
            // next redraw, so each tap appeared to show one too few.
            .contentTransition(.identity)
            Button(intent: DictateIdeaIntent()) {
                Label("Dictate", systemImage: "mic.fill")
                    .font(.title3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}
