import AppIntents
import SwiftUI
import WidgetKit

/// The widget's face on the Lock Screen: a round button that starts listening, without opening the app.
///
/// Check it on an iPhone (`docs/decisions/77-lock-screen-widget-dictates.md`): a `Button(intent:)` here once opened the
/// app without running its intent.
struct SnapperLockScreenView: View {
    var body: some View {
        Button(intent: DictateIdeaIntent()) {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .accessibilityLabel("Dictate an Idea")
            }
        }
        .buttonStyle(.plain)
    }
}
