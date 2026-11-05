/// Every service the app needs, built once at the composition root (`BufferSnapApp`) and handed down.
public struct AppEnvironment: Sendable {
    public let captureStore: any CaptureStore
    public let auth: any AuthService
    public let speech: any SpeechTranscriber
    /// The one queue, on the one `AuthService`: everything that sends goes through this.
    public let submissions: SubmissionQueue
    public let connectivity: any ConnectivityMonitor

    public init(
        captureStore: any CaptureStore,
        auth: any AuthService,
        speech: any SpeechTranscriber,
        bufferClient: any BufferClient,
        connectivity: any ConnectivityMonitor
    ) {
        self.captureStore = captureStore
        self.auth = auth
        self.speech = speech
        submissions = SubmissionQueue(store: captureStore, auth: auth, client: bufferClient)
        self.connectivity = connectivity
    }

    /// An environment of mocks: an in-memory store that starts with `seed`, a sign-in that always succeeds, a
    /// transcriber that hears nothing, a Buffer that accepts everything, and a connection that never changes.
    public static func mock(seed: [Capture]) -> AppEnvironment {
        AppEnvironment(
            captureStore: InMemoryCaptureStore(seed: seed),
            auth: MockAuthService(),
            speech: MockSpeechTranscriber(),
            bufferClient: MockBufferClient(),
            connectivity: MockConnectivityMonitor()
        )
    }
}
