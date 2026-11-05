/// Every service the app needs, built once at the composition root (`BufferSnapApp`) and handed down.
public struct AppEnvironment: Sendable {
    public let captureStore: any CaptureStore
    public let auth: any AuthService
    public let speech: any SpeechTranscriber

    public init(captureStore: any CaptureStore, auth: any AuthService, speech: any SpeechTranscriber) {
        self.captureStore = captureStore
        self.auth = auth
        self.speech = speech
    }

    /// An environment of mocks: an in-memory store that starts with `seed`, a sign-in that always succeeds, and a
    /// transcriber that hears nothing.
    public static func mock(seed: [Capture]) -> AppEnvironment {
        AppEnvironment(
            captureStore: InMemoryCaptureStore(seed: seed),
            auth: MockAuthService(),
            speech: MockSpeechTranscriber()
        )
    }
}
