import AppIntents
import BufferSnapCore
import OSLog

/// What the "Dictate an Idea" control and every widget's button run: listens and saves what's said, without opening the
/// app. A second press stops it.
///
/// `LiveActivityIntent` makes the system run it in the app's process, where the microphone and the capture store are,
/// even with the app closed (#57). It's compiled into both targets, as the widget's buttons need, but only the app can
/// do the work, so the app sets `onRun` at launch. It stays `nil` in the widget's process.
struct DictateIdeaIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Dictate an Idea"
    static let description = IntentDescription("Listens and saves what you say as an idea, without opening BufSnap.")
    // Only the control and the widget run this; it has no place in Shortcuts or Spotlight.
    static let isDiscoverable = false
    // As in the #57 spike, which ran it from a control on the Lock Screen too.
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    /// Stays out of the way, unless there's no Live Activity to say why it couldn't listen.
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes {
        [.background, .foreground(.dynamic)]
    }

    /// Set once by the app at launch: `HandsFreeDictationSession.press()`.
    @MainActor static var onRun: (@MainActor () async -> HandsFreeDictationSession.PressResult)?

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let onRun = Self.onRun else {
            Logger().error("Dictate an Idea ran where the app can't listen")
            return .result()
        }
        let result = await onRun()
        if result == .needsTheApp, #available(iOS 26.0, *) {
            try await continueInForeground(alwaysConfirm: false)
        }
        return .result()
    }
}

/// The Live Activity's Stop button. It needs no passcode, on an iPhone that's locked too (#57).
struct StopDictationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Dictating"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    /// Set once by the app at launch: `HandsFreeDictationSession.stop()`.
    @MainActor static var onRun: (@MainActor () async -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        await Self.onRun?()
        return .result()
    }
}
