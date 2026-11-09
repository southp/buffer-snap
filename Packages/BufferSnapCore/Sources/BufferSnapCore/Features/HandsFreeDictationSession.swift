import Foundation

/// Runs a dictation started outside the app: listens, shows the words in the Live Activity, and saves them as a
/// capture.
///
/// There's one of these, in the app's process, built by `BufferSnapApp`. The intents run in that process but each
/// press may get a new intent, so they only call `press()` and `stop()` here, and every bit of state lives in this one
/// owner. The rules are `HandsFreeDictation`'s; this does what it says.
@MainActor
public final class HandsFreeDictationSession {
    /// What a press needs from whoever made it.
    public enum PressResult: Sendable, Equatable {
        case done
        /// There's no Live Activity to say what happened on, so only the app on screen can.
        case needsTheApp
    }

    public private(set) var dictation = HandsFreeDictation()

    private let speech: any SpeechTranscriber
    private let store: any CaptureStore
    private let display: any DictationDisplay
    private let keepAlive: any DictationKeepAlive
    private let clock: any DictationClock
    private let onSaved: @MainActor () async -> Void
    private let finalWordsTimeout: TimeInterval

    private var listening: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var finalWordsDeadline: Task<Void, Never>?
    /// Reasons the process must stay awake: the end of a dictation, and each send.
    private var keepAliveHolds = 0
    private var isHoldingForDictation = false
    private var hadNowhereToShow = false
    /// A press found the permission not asked for yet, which only the app on screen can ask for.
    public private(set) var needsPermissionPrompt = false

    /// - Parameters:
    ///   - onSaved: Runs after each capture is stored, which is when it can start on its way to Buffer. The process is
    ///     kept awake until it returns.
    ///   - finalWordsTimeout: How long to wait for the recognizer's last words after a stop, before going with what
    ///     it has heard so far.
    public init(
        speech: any SpeechTranscriber,
        store: any CaptureStore,
        display: any DictationDisplay,
        keepAlive: any DictationKeepAlive,
        clock: any DictationClock = SystemDictationClock(),
        onSaved: @escaping @MainActor () async -> Void = {},
        finalWordsTimeout: TimeInterval = 3
    ) {
        self.speech = speech
        self.store = store
        self.display = display
        self.keepAlive = keepAlive
        self.clock = clock
        self.onSaved = onSaved
        self.finalWordsTimeout = finalWordsTimeout
    }

    /// The control, the Action button or the widget: starts listening, or stops.
    ///
    /// Returns once listening has started or the dictation has stopped, not when it ends.
    @discardableResult
    public func press() async -> PressResult {
        hadNowhereToShow = false
        await perform(dictation.press(at: clock.now))
        return hadNowhereToShow ? .needsTheApp : .done
    }

    /// The Live Activity's Stop button.
    public func stop() async {
        await perform(dictation.stopTapped())
    }

    /// Asks for the microphone and speech recognition if a press found them not asked for yet. For when the app comes
    /// to the foreground, the only time the system lets it ask.
    public func askForPermissionIfNeeded() async {
        guard needsPermissionPrompt else {
            return
        }
        needsPermissionPrompt = false
        _ = await speech.requestPermission()
    }

    private func perform(_ command: HandsFreeDictation.Command) async {
        switch command {
        case .none:
            break
        case .start:
            await start()
        case .finish:
            await finish()
        case .save(let text):
            await save(text)
        case .dismiss:
            dismiss()
        }
    }

    private func start() async {
        let permission = await speech.permission()
        guard permission == .granted else {
            needsPermissionPrompt = permission == .undetermined
            couldNotStart(.needsPermission)
            return
        }
        // Before the mic: an `AudioRecordingIntent` that ends with the audio session active and no Live Activity is a
        // fatal error in AppIntents, so without one the mic stays off (`docs/decisions/69-no-live-activity-no-mic.md`).
        guard showStatus() else {
            couldNotStart(.couldNotListen)
            return
        }
        let stream: AsyncThrowingStream<String, any Error>
        do {
            stream = try await speech.start()
        } catch {
            couldNotStart(.couldNotListen)
            return
        }
        let command = dictation.didStartListening(at: clock.now)
        listening = Task {
            await listen(to: stream)
        }
        scheduleDeadline()
        await perform(command)
    }

    private func couldNotStart(_ outcome: HandsFreeDictation.Outcome) {
        dictation.couldNotStart(outcome, at: clock.now)
        showOutcome()
    }

    private func finish() async {
        holdForDictation()
        deadline?.cancel()
        showStatus()
        await speech.finish()
        // The recognizer may never send its last words, so cancelling ends the stream with what it has.
        let giveUpAt = clock.now + finalWordsTimeout
        finalWordsDeadline = Task { [clock, speech] in
            do {
                try await clock.sleep(for: giveUpAt.timeIntervalSince(clock.now))
            } catch {
                return
            }
            await speech.cancel()
        }
    }

    private func listen(to stream: AsyncThrowingStream<String, any Error>) async {
        var failed = false
        do {
            for try await words in stream {
                let wasListening = dictation.phase == .listening
                dictation.heard(words, at: clock.now)
                showStatus()
                if wasListening {
                    scheduleDeadline()
                }
            }
        } catch {
            failed = (error as? SpeechTranscriberError) != .noSpeech
        }
        finalWordsDeadline?.cancel()
        finalWordsDeadline = nil
        listening = nil
        let command = dictation.listeningEnded(failed: failed, at: clock.now)
        await perform(command)
        if case .ended = dictation.phase {
            showOutcome()
        }
    }

    private func save(_ text: String) async {
        holdForDictation()
        do {
            try await store.add(Capture(kind: .text, text: text))
            dictation.saveEnded(succeeded: true, at: clock.now)
        } catch {
            dictation.saveEnded(succeeded: false, at: clock.now)
            return
        }
        // The send outlives the outcome on screen, and keeps the process awake until it's done.
        holdKeepAlive()
        Task {
            await onSaved()
            releaseKeepAlive()
        }
    }

    private func showOutcome() {
        holdForDictation()
        showStatus()
        scheduleDeadline()
    }

    private func dismiss() {
        deadline?.cancel()
        deadline = nil
        display.dismiss()
        if isHoldingForDictation {
            isHoldingForDictation = false
            releaseKeepAlive()
        }
    }

    /// Returns false if there's a status to show but nowhere to show it.
    @discardableResult
    private func showStatus() -> Bool {
        guard let status = dictation.status else {
            return true
        }
        let isShowing = display.show(status)
        if !isShowing {
            hadNowhereToShow = true
        }
        return isShowing
    }

    /// Wakes up at the next silence, time limit or end of the outcome, whichever `dictation` says comes first.
    private func scheduleDeadline() {
        deadline?.cancel()
        guard let next = dictation.nextDeadline else {
            deadline = nil
            return
        }
        deadline = Task { [clock] in
            do {
                try await clock.sleep(for: next.timeIntervalSince(clock.now))
            } catch {
                return
            }
            await self.deadlinePassed()
        }
    }

    private func deadlinePassed() async {
        let command = dictation.tick(at: clock.now)
        if command == .none {
            // Woken early, or by a deadline that moved: wait for the next one.
            scheduleDeadline()
            return
        }
        await perform(command)
    }

    // MARK: Keeping the process awake

    private func holdForDictation() {
        guard !isHoldingForDictation else {
            return
        }
        isHoldingForDictation = true
        holdKeepAlive()
    }

    private func holdKeepAlive() {
        if keepAliveHolds == 0 {
            keepAlive.begin()
        }
        keepAliveHolds += 1
    }

    private func releaseKeepAlive() {
        keepAliveHolds -= 1
        if keepAliveHolds == 0 {
            keepAlive.end()
        }
    }
}
