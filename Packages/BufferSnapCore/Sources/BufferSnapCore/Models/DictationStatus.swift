import Foundation

/// What the Live Activity shows of a dictation started outside the app.
///
/// It's also the Live Activity's content state, which ActivityKit stores and hands to the widget's process, so it's
/// `Codable` and `Hashable`. Core can't import ActivityKit, so the app's attributes use this type as their state.
public struct DictationStatus: Codable, Hashable, Sendable {
    public enum Phase: String, Codable, Hashable, Sendable {
        case listening
        /// Stopped, and waiting for the last words or the save.
        case finishing
        case saved
        case nothingHeard
        /// The microphone or speech recognition isn't allowed, or hasn't been asked for yet.
        case needsPermission
        case signedOut
        case couldNotListen
        case couldNotSave
    }

    public var phase: Phase
    /// Everything heard so far.
    public var words: String
    /// When listening started.
    public var startedAt: Date
    /// When listening stops by itself at the latest. Only a listening status shows a timer.
    public var endsAt: Date

    public init(phase: Phase, words: String = "", startedAt: Date, endsAt: Date) {
        self.phase = phase
        self.words = words
        self.startedAt = startedAt
        self.endsAt = endsAt
    }

    /// Whether the mic is on. A timer only means something then, so nothing else shows one.
    public var isListening: Bool {
        phase == .listening
    }
}
