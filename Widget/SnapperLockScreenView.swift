import SwiftUI
import WidgetKit

/// The widget's face on the Lock Screen: a round button that opens the capture screen.
struct SnapperLockScreenView: View {
    var body: some View {
        Button(intent: OpenCaptureIntent()) {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .accessibilityLabel("Capture")
            }
        }
        .buttonStyle(.plain)
    }
}
