import BufferSnapCore
import SwiftUI

extension View {
    /// Says why a press of Dictate an Idea didn't listen, and offers the setting that fixes it, if there's one.
    func dictationNotice(_ notice: DictationNotice?, onDismiss: @escaping () -> Void) -> some View {
        modifier(DictationNoticeAlert(notice: notice, onDismiss: onDismiss))
    }
}

private struct DictationNoticeAlert: ViewModifier {
    let notice: DictationNotice?
    let onDismiss: () -> Void

    /// The last notice shown, so the title doesn't change while the alert goes away.
    @State private var lastNotice: DictationNotice?
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        let shown = notice ?? lastNotice
        content
            .alert(
                shown.map { Text($0.alertTitle) } ?? Text(verbatim: ""),
                isPresented: Binding(
                    get: { notice != nil },
                    set: { isPresented in
                        if !isPresented {
                            onDismiss()
                        }
                    }
                ),
                presenting: shown
            ) { notice in
                if notice.canOpenSettings {
                    Button("Open Settings") {
                        if let settings = URL(string: UIApplication.openSettingsURLString) {
                            openURL(settings)
                        }
                    }
                    Button("Not Now", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: { notice in
                Text(notice.alertMessage)
            }
            .onChange(of: notice) { _, notice in
                if let notice {
                    lastNotice = notice
                }
            }
    }
}

extension DictationNotice {
    fileprivate var alertTitle: LocalizedStringResource {
        switch self {
        case .liveActivitiesOff:
            "Turn On Live Activities"
        case .microphoneOff:
            "Turn On the Microphone"
        case .speechRecognitionOff:
            "Turn On Speech Recognition"
        case .restricted:
            "Dictation Isn't Allowed"
        }
    }

    fileprivate var alertMessage: LocalizedStringResource {
        switch self {
        case .liveActivitiesOff:
            "BufSnap shows what it hears and a Stop button in a Live Activity, so it can't listen while they're off."
        case .microphoneOff:
            "BufSnap needs the microphone to hear your idea. Turn it on in Settings, then press Dictate an Idea again."
        case .speechRecognitionOff:
            """
            BufSnap needs speech recognition to turn what you say into text. Turn it on in Settings, then press \
            Dictate an Idea again.
            """
        case .restricted:
            """
            This iPhone doesn't let BufSnap use the microphone or speech recognition, for example because of Screen \
            Time. Whoever manages it can change that.
            """
        }
    }
}
