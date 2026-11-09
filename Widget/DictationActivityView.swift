import AppIntents
import BufferSnapCore
import SwiftUI

/// The dictation's Live Activity on the Lock Screen: what's happening, the words so far and, only while listening, how
/// long it's been listening and Stop.
struct DictationActivityView: View {
    let status: DictationStatus
    /// Freezes the timer at this time, for snapshots. Live, the system keeps it going.
    var timerPausedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                DictationTitle(status: status)
                    .font(.headline)
                Spacer(minLength: 0)
                if status.isListening {
                    DictationTimer(status: status, pausedAt: timerPausedAt)
                        .font(.headline)
                    DictationStopButton()
                }
            }
            Text(status.detail)
                .font(.body)
                .foregroundStyle(status.words.isEmpty ? .secondary : .primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}

/// What's happening, with its symbol.
struct DictationTitle: View {
    let status: DictationStatus

    var body: some View {
        Label(status.title, systemImage: status.symbolName)
            .foregroundStyle(status.tint)
    }
}

/// How long it's been listening. It stops by itself at the time limit, when listening does. Only listening shows it: a
/// timer that kept going after "Saved" was a bug the #57 spike found.
struct DictationTimer: View {
    let status: DictationStatus
    var pausedAt: Date?

    var body: some View {
        Text(
            timerInterval: status.startedAt...status.endsAt,
            pauseTime: pausedAt,
            countsDown: false,
            showsHours: false
        )
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .frame(width: 44)
    }
}

/// Stops listening. It needs no passcode.
///
/// It's an icon because the Dynamic Island's trailing region, which it shares with the timer, is too narrow for the
/// word: "Stop" wrapped there as "Sto / p". The label stays "Stop" for VoiceOver, and the large control size keeps it
/// over 44 points, so it's as easy to hit as the word was.
struct DictationStopButton: View {
    var body: some View {
        Button(intent: StopDictationIntent()) {
            Label("Stop", systemImage: "stop.fill")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .tint(.red)
    }
}

extension DictationStatus {
    var title: String {
        switch phase {
        case .listening:
            "Listening"
        case .finishing:
            "Finishing…"
        case .saved:
            "Saved"
        case .nothingHeard:
            "Nothing heard"
        case .needsPermission:
            "Can't listen yet"
        case .couldNotListen:
            "Couldn't listen"
        case .couldNotSave:
            "Couldn't save"
        }
    }

    /// The words, or what to do about it when there are none to show.
    var detail: String {
        switch phase {
        case .listening, .finishing, .saved:
            words.isEmpty ? "Say your idea" : words
        case .nothingHeard:
            "Nothing was saved."
        case .needsPermission:
            "Open BufSnap to allow the microphone and speech recognition, or turn them on in Settings."
        case .couldNotListen:
            "Try again in a moment."
        case .couldNotSave:
            "Open BufSnap and try again."
        }
    }

    var symbolName: String {
        switch phase {
        case .listening, .finishing:
            "mic.fill"
        case .saved:
            "checkmark.circle.fill"
        case .nothingHeard:
            "mic.slash"
        case .needsPermission, .couldNotListen, .couldNotSave:
            "exclamationmark.circle"
        }
    }

    var tint: Color {
        switch phase {
        case .listening:
            .red
        case .finishing, .nothingHeard:
            .secondary
        case .saved:
            .green
        case .needsPermission, .couldNotListen, .couldNotSave:
            .orange
        }
    }
}
