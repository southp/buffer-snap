import AppIntents
import SwiftUI

/// The dictation widget's face: one button, all of it, that starts listening.
struct DictateWidgetView: View {
    var body: some View {
        Button(intent: DictateIdeaIntent()) {
            VStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Text("Dictate an Idea")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
