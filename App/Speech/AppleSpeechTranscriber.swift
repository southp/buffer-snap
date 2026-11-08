@preconcurrency import AVFoundation
import BufferSnapCore
import OSLog
@preconcurrency import Speech

/// `SpeechTranscriber` on the microphone, using `AVAudioEngine` and `SFSpeechRecognizer`. The module name tells it from
/// the iOS 26 class of the same name in `Speech`.
///
/// It lives in the app rather than Core because `AVAudioSession` doesn't exist on macOS, where Core's tests run. It
/// holds on to no audio or text: each buffer goes straight to the recognizer, and each result straight to the stream.
actor AppleSpeechTranscriber: BufferSnapCore.SpeechTranscriber {
    /// What to listen with. The defaults are what the app ships with (`docs/decisions/42-dictation-language.md`).
    struct Options: Sendable {
        /// A language to use instead of the iPhone's own.
        var language: String?
        /// Keeps the audio on the iPhone, where its language allows that. Otherwise iOS chooses.
        var requiresOnDevice = false
    }

    /// One hold of the mic.
    private struct Run {
        let id: UUID
        let recognizer: SFSpeechRecognizer
        let engine: AVAudioEngine
        let request: SFSpeechAudioBufferRecognitionRequest
        let continuation: AsyncThrowingStream<String, any Error>.Continuation
        let interruptionObserver: any NSObjectProtocol
        var task: SFSpeechRecognitionTask?
        var isAudioRunning = true
    }

    private let logger = Logger()
    private var run: Run?
    private let mixesWithOthers: Bool

    /// - Parameter mixesWithOthers: For listening while the app isn't on screen, as a dictation started from a control
    ///   does. An app in the background can't take the audio from others: `.record` fails there with `!int`.
    init(mixesWithOthers: Bool = false) {
        self.mixesWithOthers = mixesWithOthers
    }

    func permission() -> SpeechPermission {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let microphone = AVAudioApplication.shared.recordPermission
        if microphone == .denied {
            return .microphoneDenied
        }
        switch speech {
        case .denied:
            return .speechRecognitionDenied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .undetermined
        case .authorized:
            return microphone == .granted ? .granted : .undetermined
        @unknown default:
            return .restricted
        }
    }

    /// Asks for the microphone first. If that's refused, there's no reason to ask for speech recognition too.
    func requestPermission() async -> SpeechPermission {
        _ = await AVAudioApplication.requestRecordPermission()
        if AVAudioApplication.shared.recordPermission == .granted {
            await Self.requestSpeechRecognition()
        }
        return permission()
    }

    func start() async throws -> AsyncThrowingStream<String, any Error> {
        cancel()
        let options = Options()
        // Not `Locale.current`: this app only has English strings, so that's English on a phone set to Chinese.
        let language = options.language ?? Locale.preferredLanguages.first ?? "en-US"
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)), recognizer.isAvailable else {
            throw SpeechTranscriberError.unavailable
        }
        let requiresOnDevice = options.requiresOnDevice && recognizer.supportsOnDeviceRecognition
        do {
            return try listen(with: recognizer, requiresOnDevice: requiresOnDevice)
        } catch {
            logger.error("Can't start listening: \(error)")
            Self.deactivateAudioSession(logger: logger)
            throw SpeechTranscriberError.unavailable
        }
    }

    func finish() {
        stopAudio()
        run?.request.endAudio()
    }

    func cancel() {
        guard let run else {
            return
        }
        run.continuation.finish()
        stopAudio()
        run.task?.cancel()
        end(run)
    }

    private func listen(
        with recognizer: SFSpeechRecognizer,
        requiresOnDevice: Bool
    ) throws -> AsyncThrowingStream<String, any Error> {
        let session = try Self.activateAudioSession(mixesWithOthers: mixesWithOthers)

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = requiresOnDevice
        request.addsPunctuation = true
        request.taskHint = .dictation

        // With no usable input, such as during a call, installing the tap would crash on an exception, not throw.
        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw SpeechTranscriberError.unavailable
        }
        Self.installTap(on: engine.inputNode, format: format, feeding: request)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            throw error
        }

        let (stream, continuation) = AsyncThrowingStream<String, any Error>.makeStream()
        let id = UUID()
        let onInterrupted: @Sendable () -> Void = { [weak self] in
            Task {
                await self?.interrupted(id: id)
            }
        }
        let onRecognitionEnd: @Sendable () -> Void = { [weak self] in
            Task {
                await self?.recognitionEnded(id: id)
            }
        }
        var run = Run(
            id: id,
            recognizer: recognizer,
            engine: engine,
            request: request,
            continuation: continuation,
            interruptionObserver: Self.observeInterruptions(of: session, onBegan: onInterrupted)
        )
        run.task = Self.recognitionTask(
            recognizer: recognizer,
            request: request,
            continuation: continuation,
            onEnd: onRecognitionEnd
        )
        self.run = run
        return stream
    }

    /// Something else took the audio. What's been heard is already with the reader of the stream.
    private func interrupted(id: UUID) {
        guard let run, run.id == id else {
            return
        }
        run.continuation.finish(throwing: SpeechTranscriberError.interrupted)
        stopAudio()
        run.task?.cancel()
        end(run)
    }

    /// The recognizer is done, after a release or by itself. By itself leaves the audio running, so stop that too.
    private func recognitionEnded(id: UUID) {
        guard let run, run.id == id else {
            return
        }
        stopAudio()
        end(run)
    }

    private func stopAudio() {
        guard let current = run, current.isAudioRunning else {
            return
        }
        current.engine.stop()
        current.engine.inputNode.removeTap(onBus: 0)
        run?.isAudioRunning = false
        Self.deactivateAudioSession(logger: logger)
    }

    private func end(_ run: Run) {
        NotificationCenter.default.removeObserver(run.interruptionObserver)
        self.run = nil
    }

    // The closures below run on Apple's own threads and queues, so they're made in nonisolated static functions.
    // Formed in the actor, they'd inherit its isolation and trap when called from anywhere else.

    private nonisolated static func requestSpeechRecognition() async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { _ in
                done.resume()
            }
        }
    }

    private nonisolated static func installTap(
        on input: AVAudioInputNode,
        format: AVAudioFormat,
        feeding request: SFSpeechAudioBufferRecognitionRequest
    ) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    private nonisolated static func observeInterruptions(
        of session: AVAudioSession,
        onBegan: @escaping @Sendable () -> Void
    ) -> any NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: nil
        ) { notification in
            let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            if type == .began {
                onBegan()
            }
        }
    }

    private nonisolated static func recognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        continuation: AsyncThrowingStream<String, any Error>.Continuation,
        onEnd: @escaping @Sendable () -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            if let result {
                let words = result.bestTranscription.formattedString
                continuation.yield(words)
                if result.isFinal {
                    continuation.finish()
                    onEnd()
                    return
                }
            }
            if let error {
                continuation.finish(throwing: transcriberError(for: error, recognizer: recognizer))
                onEnd()
            }
        }
    }

    private nonisolated static func transcriberError(
        for error: any Error,
        recognizer: SFSpeechRecognizer
    ) -> SpeechTranscriberError {
        let error = error as NSError
        // Undocumented, but it's what the recognizer has long sent when it hears nothing.
        if error.domain == "kAFAssistantErrorDomain" && error.code == 1110 {
            return .noSpeech
        }
        return recognizer.isAvailable ? .failed : .unavailable
    }

    private nonisolated static func activateAudioSession(mixesWithOthers: Bool) throws -> AVAudioSession {
        let session = AVAudioSession.sharedInstance()
        if mixesWithOthers {
            // What recorded from a control with the app closed, on an iPhone (#57).
            try session.setCategory(.playAndRecord, mode: .default, options: .mixWithOthers)
        } else {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        }
        // Recording silences haptics by default, and they're how a thumb on the mic knows it's listening.
        try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        return session
    }

    private nonisolated static func deactivateAudioSession(logger: Logger) {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Can't deactivate the audio session: \(error)")
        }
    }

}
