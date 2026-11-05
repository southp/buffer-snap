extension CaptureModel {
    /// How holding the mic is going. While listening, the words heard so far are in `text`.
    public enum DictationState: Sendable, Equatable {
        case idle
        case listening
        /// Released, and waiting for the recognizer's last words.
        case finishing
        case finished(DictationOutcome)
        /// Anything heard is still in `text`, to edit or save by hand.
        case failed(DictationFailure)
    }

    /// What a release led to.
    public enum DictationOutcome: Sendable, Equatable {
        case saved
        /// The store failed, as `saveResult` also says, and the words are still in `text`.
        case saveFailed
        case nothingHeard
        /// Over the limit, so nothing was saved and the words are in `text` to edit.
        case tooLong
    }

    /// Why dictation couldn't start or carry on.
    public enum DictationFailure: Sendable, Equatable {
        case microphoneDenied
        case speechRecognitionDenied
        case restricted
        case unavailable
        case interrupted
        /// Listening stopped by itself while the mic was still held, such as at the recognizer's time limit.
        case stoppedEarly
        case recognitionFailed

        /// Whether it comes from the user's settings, so it stays true until they change them.
        var isAboutPermission: Bool {
            switch self {
            case .microphoneDenied, .speechRecognitionDenied, .restricted:
                true
            case .unavailable, .interrupted, .stoppedEarly, .recognitionFailed:
                false
            }
        }

        /// The failure a permission amounts to, if any.
        init?(_ permission: SpeechPermission) {
            switch permission {
            case .microphoneDenied:
                self = .microphoneDenied
            case .speechRecognitionDenied:
                self = .speechRecognitionDenied
            case .restricted:
                self = .restricted
            case .granted, .undetermined:
                return nil
            }
        }

        init(_ error: any Error) {
            switch error as? SpeechTranscriberError {
            case .unavailable:
                self = .unavailable
            case .interrupted:
                self = .interrupted
            case .noSpeech, .failed, nil:
                self = .recognitionFailed
            }
        }
    }
}
