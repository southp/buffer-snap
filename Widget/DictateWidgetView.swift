import AppIntents
import SwiftUI

/// The dictation widget's face: one button, all of it, that starts listening. BufSnap's dictate symbol, the Doodle
/// Bulb, in a Tomato circle on Sun, with ink outlines. Sun stays Sun in dark mode, so everything on it is
/// `Theme.onColor`, never `Theme.ink`, which turns cream.
struct DictateWidgetView: View {
    var body: some View {
        Button(intent: DictateIdeaIntent()) {
            VStack(spacing: 12) {
                // Decorative: the button's text says what it does, and VoiceOver would read the asset's name.
                Image(decorative: "bufsnap.dictate")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.onColor)
                    .frame(width: 62, height: 62)
                    .background {
                        OutlinedShape(shape: Circle(), fill: Theme.tomato, ink: Theme.onColor, shadow: Theme.chipShadow)
                    }
                Text("Dictate an Idea")
                    .font(.inter(.headline, weight: .bold))
                    .foregroundStyle(Theme.onColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// What's behind the widget's face: Sun, inside an ink outline that follows the widget's corners.
struct DictateWidgetBackground: View {
    var body: some View {
        ZStack {
            Theme.sun
            ContainerRelativeShape()
                .strokeBorder(Theme.onColor, lineWidth: Theme.borderWidth)
        }
    }
}
