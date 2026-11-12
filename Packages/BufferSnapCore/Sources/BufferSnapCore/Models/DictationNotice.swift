/// Why a press of Dictate an Idea couldn't listen, as the app tells it: in an alert when the press opened the app, and,
/// for a refused permission, in a row at the top of the list for as long as it's refused.
public enum DictationNotice: Sendable, Equatable {
    /// There was no Live Activity to show the dictation on: `docs/decisions/69-no-live-activity-no-mic.md`.
    case liveActivitiesOff
    case microphoneOff
    case speechRecognitionOff
    /// The device doesn't allow it, for example through Screen Time, so nothing in the app's settings changes it.
    case restricted

    /// What a permission needs said about it, or `nil` if nothing: it's granted, or it hasn't been asked for yet, which
    /// opening the app does.
    public init?(_ permission: SpeechPermission) {
        switch permission {
        case .granted, .undetermined:
            return nil
        case .microphoneDenied:
            self = .microphoneOff
        case .speechRecognitionDenied:
            self = .speechRecognitionOff
        case .restricted:
            self = .restricted
        }
    }

    /// What the app says when a press opened it for `reason`, or `nil` if there's nothing to say.
    public init?(_ reason: HandsFreeDictationSession.NeedsTheAppReason) {
        switch reason {
        case .liveActivitiesOff:
            self = .liveActivitiesOff
        case .permission(let permission):
            self.init(permission)
        }
    }

    /// Whether the app's page in Settings has the switch that fixes it.
    public var canOpenSettings: Bool {
        self != .restricted
    }
}
