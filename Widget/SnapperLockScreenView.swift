import BufferSnapCore
import SwiftUI
import WidgetKit

/// The widget's face on the Lock Screen: a round tap target that opens the capture screen.
///
/// Not a `Button(intent:)`, unlike the other faces. On an iPhone, tapping that here opened the app where it was,
/// without running the intent. A `widgetURL` is what Apple documents for opening the app from a widget
/// (`docs/decisions/41-lock-screen-widget-url.md`).
struct SnapperLockScreenView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "bolt.fill")
                .font(.title2)
                .accessibilityLabel("Capture")
        }
        .widgetURL(AppLink.capture.url)
    }
}
