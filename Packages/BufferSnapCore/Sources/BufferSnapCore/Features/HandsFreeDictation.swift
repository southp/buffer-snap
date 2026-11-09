import Foundation

/// The rules of a dictation started outside the app, from a control, the Action button or the widget: when it starts,
/// what stops it, and what it ends with.
///
/// It's a plain value with no clock and no I/O, so every rule is a unit test. `HandsFreeDictationSession` feeds it
/// each event with the time it happened, and does what it returns.
///
/// A press only ever starts a dictation from idle. While one is starting, listening, finishing or showing how it
/// ended, a press stops it or does nothing, so however presses and timers interleave, there's never a second one
/// (`docs/decisions/58-press-while-busy.md`).
public struct HandsFreeDictation: Sendable, Equatable {
    /// Seconds without new words, once something's been heard, before listening stops by itself.
    public static let silenceLimit: TimeInterval = 3
    /// Seconds of listening in all.
    public static let timeLimit: TimeInterval = 60
    /// Seconds the outcome stays on screen before the Live Activity goes away.
    public static let outcomeDuration: TimeInterval = 3

    public enum Phase: Sendable, Equatable {
        case idle
        /// Pressed: checking sign-in and permission, and turning the mic on.
        case starting
        case listening
        /// Stopped, and waiting for the recognizer's last words.
        case finishing
        case saving
        /// Showing how it ended, until `outcomeDuration` has passed.
        case ended(Outcome)
    }

    public enum Outcome: Sendable, Equatable {
        case saved
        case nothingHeard
        case needsPermission
        case couldNotListen
        case couldNotSave
    }

    /// What the session must do next.
    public enum Command: Sendable, Equatable {
        case none
        /// Check permission, then turn the mic on.
        case start
        /// Ask the recognizer for its last words.
        case finish
        /// Store this text as a capture.
        case save(String)
        /// Take the Live Activity away.
        case dismiss
    }

    public private(set) var phase = Phase.idle
    /// Everything heard so far in this dictation.
    public private(set) var words = ""
    public private(set) var startedAt = Date.distantPast
    private var lastWordsAt = Date.distantPast
    private var endedAt = Date.distantPast
    private var isStopRequested = false

    public init() {}

    /// The next time `tick(at:)` could change something, if anything is waiting on the time.
    public var nextDeadline: Date? {
        switch phase {
        case .listening:
            let limit = startedAt + Self.timeLimit
            guard hasHeardSomething else {
                return limit
            }
            return min(limit, lastWordsAt + Self.silenceLimit)
        case .ended:
            return endedAt + Self.outcomeDuration
        case .idle, .starting, .finishing, .saving:
            return nil
        }
    }

    /// What the Live Activity shows, or `nil` when there's nothing to show.
    public var status: DictationStatus? {
        let phase: DictationStatus.Phase
        switch self.phase {
        case .idle:
            return nil
        case .starting, .listening:
            phase = .listening
        case .finishing, .saving:
            phase = .finishing
        case .ended(let outcome):
            phase = DictationStatus.Phase(outcome)
        }
        return DictationStatus(
            phase: phase,
            words: words,
            startedAt: startedAt,
            endsAt: startedAt + Self.timeLimit
        )
    }

    /// The control, the Action button or the widget was pressed.
    public mutating func press(at now: Date) -> Command {
        switch phase {
        case .idle:
            return begin(at: now)
        case .ended:
            // Most likely meant to stop a dictation that silence had just stopped, so it mustn't start another.
            guard now >= endedAt + Self.outcomeDuration else {
                return .none
            }
            return begin(at: now)
        case .starting:
            isStopRequested = true
            return .none
        case .listening:
            return stop()
        case .finishing, .saving:
            return .none
        }
    }

    /// The Live Activity's Stop button. It only ever stops.
    public mutating func stopTapped() -> Command {
        switch phase {
        case .starting:
            isStopRequested = true
            return .none
        case .listening:
            return stop()
        case .idle, .finishing, .saving, .ended:
            return .none
        }
    }

    /// Sign-in and permission are fine, and the mic is on.
    public mutating func didStartListening(at now: Date) -> Command {
        guard phase == .starting else {
            return .none
        }
        phase = .listening
        lastWordsAt = now
        if isStopRequested {
            return stop()
        }
        return .none
    }

    /// Listening never started, for `outcome`'s reason.
    public mutating func couldNotStart(_ outcome: Outcome, at now: Date) {
        guard phase == .starting else {
            return
        }
        end(with: outcome, at: now)
    }

    /// The recognizer sent everything it's heard so far.
    public mutating func heard(_ newWords: String, at now: Date) {
        guard phase == .listening || phase == .finishing, newWords != words else {
            return
        }
        words = newWords
        lastWordsAt = now
    }

    /// Time passed: stops at the silence or time limit, and dismisses an outcome that's been shown long enough.
    public mutating func tick(at now: Date) -> Command {
        switch phase {
        case .listening:
            if now >= startedAt + Self.timeLimit {
                return stop()
            }
            if hasHeardSomething && now >= lastWordsAt + Self.silenceLimit {
                return stop()
            }
            return .none
        case .ended:
            guard now >= endedAt + Self.outcomeDuration else {
                return .none
            }
            phase = .idle
            return .dismiss
        case .idle, .starting, .finishing, .saving:
            return .none
        }
    }

    /// The recognizer is done, after a stop or by itself. `failed` is for a failure other than hearing no speech.
    ///
    /// Words already heard are saved whatever ended it: they're worth more than the error.
    public mutating func listeningEnded(failed: Bool, at now: Date) -> Command {
        guard phase == .listening || phase == .finishing else {
            return .none
        }
        let text = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            end(with: failed ? .couldNotListen : .nothingHeard, at: now)
            return .none
        }
        phase = .saving
        return .save(text)
    }

    /// The save asked for by `.save` is done.
    public mutating func saveEnded(succeeded: Bool, at now: Date) {
        guard phase == .saving else {
            return
        }
        end(with: succeeded ? .saved : .couldNotSave, at: now)
    }

    private var hasHeardSomething: Bool {
        !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private mutating func begin(at now: Date) -> Command {
        phase = .starting
        words = ""
        startedAt = now
        lastWordsAt = now
        isStopRequested = false
        return .start
    }

    private mutating func stop() -> Command {
        phase = .finishing
        return .finish
    }

    private mutating func end(with outcome: Outcome, at now: Date) {
        phase = .ended(outcome)
        endedAt = now
    }
}

extension DictationStatus.Phase {
    init(_ outcome: HandsFreeDictation.Outcome) {
        switch outcome {
        case .saved:
            self = .saved
        case .nothingHeard:
            self = .nothingHeard
        case .needsPermission:
            self = .needsPermission
        case .couldNotListen:
            self = .couldNotListen
        case .couldNotSave:
            self = .couldNotSave
        }
    }
}
