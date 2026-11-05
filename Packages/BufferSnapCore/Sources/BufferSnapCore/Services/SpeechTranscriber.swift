/// Whether the app may listen and turn speech into text. Listening needs both the microphone and speech recognition.
public enum SpeechPermission: Sendable, Equatable {
    /// At least one of the two hasn't been asked for, and neither is refused.
    case undetermined
    case granted
    case microphoneDenied
    case speechRecognitionDenied
    /// The device doesn't allow it, for example through parental controls, so the user can't turn it on here.
    case restricted
}

/// Why listening stopped without being asked to.
public enum SpeechTranscriberError: Error, Sendable, Equatable {
    /// Recognition can't run now: an unsupported language, no network, or a usage limit.
    case unavailable
    /// The recognizer gave up because it heard no speech.
    case noSpeech
    /// Something else took the audio, such as a phone call.
    case interrupted
    /// Recognition failed in any other way.
    case failed
}

/// Listens to the microphone and turns speech into text.
///
/// Nothing is kept: no audio is stored, and the text only reaches whoever reads the stream.
public protocol SpeechTranscriber: Sendable {
    /// The current permission, without asking the user.
    func permission() async -> SpeechPermission

    /// Asks the user for whatever hasn't been asked for yet, and returns the result.
    func requestPermission() async -> SpeechPermission

    /// Starts listening. The stream yields everything heard so far, each time it changes. It ends after `finish()`
    /// once the last words are in, or throws a `SpeechTranscriberError` if listening stops by itself.
    func start() async throws -> AsyncThrowingStream<String, any Error>

    /// Stops listening and lets the recognizer deliver its last words, which can take a moment.
    func finish() async

    /// Stops listening and ends the stream at once.
    func cancel() async
}

/// A `SpeechTranscriber` that hears only what it's told to, for tests, previews and the mocked app.
public actor MockSpeechTranscriber: SpeechTranscriber {
    public private(set) var startCount = 0
    public private(set) var requestCount = 0
    public private(set) var cancelCount = 0

    private var currentPermission: SpeechPermission
    private let answer: SpeechPermission
    private let startError: SpeechTranscriberError?
    private let finalWords: String?
    private let endsOnFinish: Bool
    private var onStart: (@Sendable () async -> Void)?
    private var continuation: AsyncThrowingStream<String, any Error>.Continuation?

    /// - Parameters:
    ///   - permission: What `permission()` reports.
    ///   - answer: What the user answers when asked, which then becomes the permission.
    ///   - startError: What `start()` throws, if anything.
    ///   - finalWords: What `finish()` yields last, if anything.
    ///   - endsOnFinish: Whether `finish()` ends the stream. Pass `false` for a recognizer that never answers.
    public init(
        permission: SpeechPermission = .granted,
        answer: SpeechPermission = .granted,
        startError: SpeechTranscriberError? = nil,
        finalWords: String? = nil,
        endsOnFinish: Bool = true
    ) {
        currentPermission = permission
        self.answer = answer
        self.startError = startError
        self.finalWords = finalWords
        self.endsOnFinish = endsOnFinish
    }

    /// Sets what runs in the middle of each `start()`, so a test can act while it's in flight.
    public func setOnStart(_ onStart: @escaping @Sendable () async -> Void) {
        self.onStart = onStart
    }

    /// Delivers `words` as everything heard so far.
    public func hear(_ words: String) {
        continuation?.yield(words)
    }

    /// Ends listening by itself, as the recognizer does at its time limit or on an error.
    public func stopByItself(throwing error: SpeechTranscriberError? = nil) {
        continuation?.finish(throwing: error)
        continuation = nil
    }

    public func permission() -> SpeechPermission {
        currentPermission
    }

    public func requestPermission() -> SpeechPermission {
        requestCount += 1
        currentPermission = answer
        return currentPermission
    }

    public func start() async throws -> AsyncThrowingStream<String, any Error> {
        startCount += 1
        await onStart?()
        if let startError {
            throw startError
        }
        let (stream, continuation) = AsyncThrowingStream<String, any Error>.makeStream()
        self.continuation = continuation
        return stream
    }

    public func finish() {
        if let finalWords {
            continuation?.yield(finalWords)
        }
        if endsOnFinish {
            continuation?.finish()
            continuation = nil
        }
    }

    public func cancel() {
        cancelCount += 1
        continuation?.finish()
        continuation = nil
    }
}
