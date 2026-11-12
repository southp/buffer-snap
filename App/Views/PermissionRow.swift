import BufferSnapCore
import SwiftUI

/// The top of the list while the microphone or speech recognition is refused: Dictate an Idea can't listen until it's
/// back on, so the list says so, with the way to Settings when there's a switch there
/// (`docs/decisions/99-say-when-a-permission-is-off.md`).
struct PermissionRow: View {
    let notice: DictationNotice

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Badge(fill: Theme.tomato) {
                    Image(systemName: "mic.slash")
                        .font(.inter(.subheadline, weight: .bold))
                }
                .accessibilityHidden(true)
                Text(title)
                    .font(.inter(.headline, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            Text(message)
                .font(.inter(.subheadline))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if notice.canOpenSettings {
                Button("Open Settings") {
                    if let settings = URL(string: UIApplication.openSettingsURLString) {
                        openURL(settings)
                    }
                }
                .buttonStyle(.paperInkSecondary)
            }
        }
    }

    private var title: LocalizedStringResource {
        switch notice {
        case .liveActivitiesOff:
            "Live Activities are off"
        case .microphoneOff:
            "Microphone is off"
        case .speechRecognitionOff:
            "Speech recognition is off"
        case .restricted:
            "Dictation isn't allowed"
        }
    }

    private var message: LocalizedStringResource {
        switch notice {
        case .liveActivitiesOff:
            "Dictate an Idea shows what it hears in a Live Activity, so it can't listen while they're off."
        case .microphoneOff:
            "Dictate an Idea can't hear you. Turn on the microphone for BufSnap in Settings."
        case .speechRecognitionOff:
            "Dictate an Idea can't turn what you say into text. Turn on speech recognition for BufSnap in Settings."
        case .restricted:
            """
            This iPhone doesn't let BufSnap use the microphone or speech recognition, for example because of \
            Screen Time. Whoever manages it can change that.
            """
        }
    }
}
