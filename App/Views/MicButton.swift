import BufferSnapCore
import SwiftUI

/// The large button to hold while speaking. It only knows press and release: a tap is just a very short hold.
struct MicButton: View {
    let dictation: CaptureModel.DictationState
    let onPress: () -> Void
    let onRelease: () -> Void

    /// Resets when the system takes the touch away too, which a drag's `onEnded` wouldn't report.
    @GestureState private var isPressed = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 44, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 112, height: 112)
            .background(color, in: Circle())
            .scaleEffect(isListening ? 1.12 : 1)
            .animation(.easeOut(duration: 0.15), value: isListening)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, isPressed, _ in
                        isPressed = true
                    }
            )
            .onChange(of: isPressed) { _, isPressed in
                if isPressed {
                    onPress()
                } else {
                    onRelease()
                }
            }
            // The thumb covers the button, so the change has to be felt as well as seen.
            .sensoryFeedback(.impact, trigger: isListening)
            .accessibilityElement()
            .accessibilityLabel("Dictate")
            .accessibilityHint("Hold, speak, and let go to save.")
            .accessibilityAddTraits(.isButton)
    }

    private var isListening: Bool {
        dictation == .listening
    }

    private var symbol: String {
        switch dictation {
        case .failed(.microphoneDenied), .failed(.speechRecognitionDenied), .failed(.restricted):
            "mic.slash.fill"
        case .listening, .finishing:
            "waveform"
        case .idle, .finished, .failed:
            "mic.fill"
        }
    }

    private var color: Color {
        switch dictation {
        case .failed(.microphoneDenied), .failed(.speechRecognitionDenied), .failed(.restricted):
            .gray
        case .listening:
            .red
        case .finishing:
            .orange
        case .idle, .finished, .failed:
            .accentColor
        }
    }
}

/// The line above the mic: how to use it, what it's doing, or why it didn't work.
struct DictationMessage: View {
    let dictation: CaptureModel.DictationState
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(isProblem ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .multilineTextAlignment(.center)
            if canFixInSettings {
                Button("Open Settings", action: onOpenSettings)
                    .font(.subheadline)
            }
        }
    }

    private var message: LocalizedStringKey {
        switch dictation {
        case .idle, .finished(.saved), .finished(.saveFailed):
            "Hold to talk"
        case .listening:
            "Listening. Let go to save."
        case .finishing:
            "Finishing up"
        case .finished(.nothingHeard):
            "Didn't hear anything. Hold the mic while you speak."
        case .finished(.tooLong):
            "Too long to save. Shorten it, then tap Save."
        case .failed(.microphoneDenied):
            "BufSnap can't use the microphone. Allow it in Settings, or type instead."
        case .failed(.speechRecognitionDenied):
            "BufSnap can't use speech recognition. Allow it in Settings, or type instead."
        case .failed(.restricted):
            "Dictation isn't allowed on this iPhone. You can still type."
        case .failed(.unavailable):
            "Dictation isn't available right now. Check your connection, or type instead."
        case .failed(.interrupted):
            "Dictation was interrupted. Anything it heard is in the box."
        case .failed(.stoppedEarly):
            "Dictation stopped. Tap Save to keep this, or hold to add more."
        case .failed(.recognitionFailed):
            "Dictation didn't work. Try again, or type instead."
        }
    }

    private var isProblem: Bool {
        switch dictation {
        case .failed, .finished(.tooLong):
            true
        case .idle, .listening, .finishing, .finished:
            false
        }
    }

    private var canFixInSettings: Bool {
        dictation == .failed(.microphoneDenied) || dictation == .failed(.speechRecognitionDenied)
    }
}
