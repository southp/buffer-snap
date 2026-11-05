import SwiftUI
import WidgetKit

/// The control for the Action button, Control Center and the Lock Screen: one press opens the capture screen.
struct OpenCaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "OpenCaptureControl") {
            ControlWidgetButton(action: OpenCaptureIntent()) {
                Label("Capture", systemImage: "bolt.fill")
            }
        }
        .displayName("Capture an Idea")
        .description("Opens BufferSnap on the capture screen.")
    }
}
