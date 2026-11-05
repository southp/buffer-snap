import Foundation
import Observation

/// The idea being typed or dictated on the capture screen, and saving it as a capture.
@Observable
@MainActor
public final class CaptureModel {
    /// What the last save did, until the text changes.
    public enum SaveResult: Sendable, Equatable {
        case saved
        case failed
    }

    /// The most characters a capture can have. A longer draft stays editable but can't be saved.
    public static let characterLimit = 300

    /// The draft, as typed.
    public private(set) var text = ""
    public private(set) var saveResult: SaveResult?
    public private(set) var dictation = DictationState.idle
    private var isSaving = false
    /// Between pressing the mic and listening, when a release has nothing to stop yet.
    private var isStartingDictation = false
    private var wasReleasedWhileStarting = false
    /// The draft from before this hold, which the words heard get added to.
    private var draftBeforeDictation = ""
    /// The words heard in this hold.
    private var heard = ""
    private var listening: Task<Void, Never>?

    private let store: any CaptureStore
    private let speech: any SpeechTranscriber
    private let finalWordsTimeout: Duration
    private let onSaved: @MainActor () -> Void

    /// - Parameters:
    ///   - finalWordsTimeout: How long to wait for the recognizer's last words after a release, before going with what
    ///     it has heard so far.
    ///   - onSaved: Runs after each capture is stored, which is when it can start on its way to Buffer.
    public init(
        store: any CaptureStore,
        speech: any SpeechTranscriber,
        finalWordsTimeout: Duration = .seconds(3),
        onSaved: @escaping @MainActor () -> Void = {}
    ) {
        self.store = store
        self.speech = speech
        self.finalWordsTimeout = finalWordsTimeout
        self.onSaved = onSaved
    }

    /// How many characters would be saved: what a person sees as one character counts as one.
    public var characterCount: Int {
        trimmedText.count
    }

    public var isOverLimit: Bool {
        characterCount > Self.characterLimit
    }

    public var canSave: Bool {
        !trimmedText.isEmpty && !isOverLimit && !isSaving && !isDictating
    }

    /// Whether the mic is in use, so the text belongs to the recognizer.
    public var isDictating: Bool {
        dictation == .listening || dictation == .finishing
    }

    /// Replaces the draft.
    public func update(text newText: String) {
        // SwiftUI can set a binding to the value it already has, which mustn't clear the result.
        guard newText != text, !isDictating else {
            return
        }
        text = newText
        saveResult = nil
        clearDictationNotice()
    }

    /// Forgets the last save's result, so "Saved" doesn't greet the next idea when the app comes back later.
    public func clearSaveResult() {
        saveResult = nil
        if case .finished = dictation {
            dictation = .idle
        }
    }

    /// Saves the draft as a pending text capture and clears it. A failed save keeps the draft, so it can be retried.
    public func save() async {
        guard canSave else {
            return
        }
        clearDictationNotice()
        isSaving = true
        defer {
            isSaving = false
        }
        let draft = text
        do {
            try await store.add(Capture(kind: .text, text: trimmedText))
            onSaved()
            // Anything typed while the write ran belongs to the next capture, so keep it.
            if text == draft {
                text = ""
                saveResult = .saved
            }
        } catch {
            saveResult = .failed
        }
    }

    /// Shows a refused permission before the mic is touched, and clears it once it's allowed again in Settings.
    public func refreshDictationPermission() async {
        let permission = await speech.permission()
        if let failure = DictationFailure(permission) {
            if !isDictating {
                dictation = .failed(failure)
            }
        } else if case .failed(let failure) = dictation, failure.isAboutPermission {
            dictation = .idle
        }
    }

    /// The mic was pressed: starts listening, or the first time, asks for permission.
    public func startDictation() async {
        guard !isStartingDictation, !isDictating, !isSaving else {
            return
        }
        isStartingDictation = true
        wasReleasedWhileStarting = false
        defer {
            isStartingDictation = false
        }
        saveResult = nil
        dictation = .idle
        var permission = await speech.permission()
        if permission == .undetermined {
            permission = await speech.requestPermission()
            // The system's prompts took the finger off the button, so the next hold is the one that listens.
            if permission == .granted {
                return
            }
        }
        if let failure = DictationFailure(permission) {
            dictation = .failed(failure)
            return
        }
        let stream: AsyncThrowingStream<String, any Error>
        do {
            stream = try await speech.start()
        } catch {
            dictation = .failed(DictationFailure(error))
            return
        }
        if wasReleasedWhileStarting {
            await speech.cancel()
            dictation = .finished(.nothingHeard)
            return
        }
        heard = ""
        draftBeforeDictation = text
        dictation = .listening
        listening = Task {
            await listen(to: stream)
        }
    }

    /// The mic was released: stops listening and, if anything was heard, saves it.
    public func finishDictation() async {
        if isStartingDictation {
            wasReleasedWhileStarting = true
            return
        }
        guard dictation == .listening, let listening else {
            return
        }
        dictation = .finishing
        await speech.finish()
        let timeout = Task { [finalWordsTimeout] in
            try? await Task.sleep(for: finalWordsTimeout)
            if !Task.isCancelled {
                listening.cancel()
            }
        }
        await listening.value
        timeout.cancel()
    }

    /// Stops listening because the app is leaving. What was heard stays in the box, unsaved.
    public func interruptDictation() async {
        if isStartingDictation {
            wasReleasedWhileStarting = true
            return
        }
        guard dictation == .listening, let listening else {
            return
        }
        dictation = .failed(.interrupted)
        await speech.cancel()
        await listening.value
    }

    private func listen(to stream: AsyncThrowingStream<String, any Error>) async {
        var failure: SpeechTranscriberError?
        do {
            for try await words in stream where !words.isEmpty {
                heard = words
                text = Self.joined(draft: draftBeforeDictation, words: words)
            }
        } catch {
            failure = error as? SpeechTranscriberError ?? .failed
        }
        // Cancelled means the last words never came, so the recognizer needs telling.
        if Task.isCancelled {
            await speech.cancel()
        }
        listening = nil
        await listeningEnded(failure: failure)
    }

    private func listeningEnded(failure: SpeechTranscriberError?) async {
        switch dictation {
        case .finishing:
            await handleRelease(failure: failure)
        case .listening:
            handleStopWhileHeld(failure: failure)
        case .idle, .finished, .failed:
            break
        }
    }

    /// A late error doesn't undo words already heard, so it only matters if there are none.
    private func handleRelease(failure: SpeechTranscriberError?) async {
        if heard.isEmpty {
            dictation = Self.stateWhenNothingHeard(failure: failure)
        } else if isOverLimit {
            dictation = .finished(.tooLong)
        } else {
            dictation = .idle
            await save()
            dictation = .finished(saveResult == .saved ? .saved : .saveFailed)
        }
    }

    /// The finger is still down and more words may be coming, so saving now could miss them without saying so.
    private func handleStopWhileHeld(failure: SpeechTranscriberError?) {
        if heard.isEmpty {
            dictation = Self.stateWhenNothingHeard(failure: failure)
        } else if let failure, failure != .noSpeech {
            dictation = .failed(DictationFailure(failure))
        } else {
            dictation = .failed(.stoppedEarly)
        }
    }

    private func clearDictationNotice() {
        switch dictation {
        case .finished:
            dictation = .idle
        case .failed(let failure) where !failure.isAboutPermission:
            dictation = .idle
        case .idle, .listening, .finishing, .failed:
            break
        }
    }

    private static func stateWhenNothingHeard(failure: SpeechTranscriberError?) -> DictationState {
        if let failure, failure != .noSpeech {
            return .failed(DictationFailure(failure))
        }
        return .finished(.nothingHeard)
    }

    /// Words go after a draft that's already there, with a space unless it ends in one.
    private static func joined(draft: String, words: String) -> String {
        guard let last = draft.last, !last.isWhitespace else {
            return draft + words
        }
        return draft + " " + words
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
