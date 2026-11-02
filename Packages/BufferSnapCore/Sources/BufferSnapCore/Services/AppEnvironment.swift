/// Every service the app needs, built once at the composition root (`BufferSnapApp`) and handed down.
public struct AppEnvironment: Sendable {
    public let captureStore: any CaptureStore
    public let auth: any AuthService

    public init(captureStore: any CaptureStore, auth: any AuthService) {
        self.captureStore = captureStore
        self.auth = auth
    }

    /// An environment of mocks: an in-memory store that starts with `seed`, and a sign-in that always succeeds.
    public static func mock(seed: [Capture]) -> AppEnvironment {
        AppEnvironment(captureStore: InMemoryCaptureStore(seed: seed), auth: MockAuthService())
    }
}
