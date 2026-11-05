import SwiftUI

/// The widget's face on the Home Screen and in the Today View: how many captures exist, and a button that opens the
/// capture screen.
struct SnapperWidgetView: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(count) captured")
                .font(.headline)
                // Don't animate: with the default transition the simulator kept drawing the previous count until the
                // next redraw, so each tap appeared to show one too few.
                .contentTransition(.identity)
            Button(intent: OpenCaptureIntent()) {
                Label("Capture", systemImage: "bolt.fill")
                    .font(.title3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}
