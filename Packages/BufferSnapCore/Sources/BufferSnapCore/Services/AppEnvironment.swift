/// Every service the app needs, built once at the composition root (`BufferSnapApp`) and handed down.
public struct AppEnvironment: Sendable {
    public let captureStore: any CaptureStore
    public let auth: any AuthService
    /// The one queue, on the one `AuthService`: everything that sends goes through this.
    public let submissions: SubmissionQueue
    public let connectivity: any ConnectivityMonitor
    public let batchWindow: any BatchWindowSetting
    /// The signed-in account between launches. It's asked for through `submissions`, which keeps Buffer's rate limit.
    public let accountStore: any AccountStore
    /// Downloads the account's picture from Buffer's bucket on S3: not Buffer's API, so not through `submissions`.
    public let avatarDownloader: any AvatarDownloader
    /// The account's picture between launches.
    public let avatarStore: any AvatarImageStore

    public init(
        captureStore: any CaptureStore,
        auth: any AuthService,
        bufferClient: any BufferClient,
        connectivity: any ConnectivityMonitor,
        batchWindow: any BatchWindowSetting,
        accountStore: any AccountStore = InMemoryAccountStore(),
        avatarDownloader: any AvatarDownloader = NoAvatarDownloader(),
        avatarStore: any AvatarImageStore = InMemoryAvatarImageStore()
    ) {
        self.captureStore = captureStore
        self.auth = auth
        submissions = SubmissionQueue(
            store: captureStore,
            auth: auth,
            client: bufferClient,
            planner: SubmissionPlanner { batchWindow.window }
        )
        self.connectivity = connectivity
        self.batchWindow = batchWindow
        self.accountStore = accountStore
        self.avatarDownloader = avatarDownloader
        self.avatarStore = avatarStore
    }

    /// An environment of mocks: an in-memory store that starts with `seed`, a sign-in that always succeeds, a
    /// Buffer that accepts everything, a connection that never changes, no batching, and no saved account or picture.
    public static func mock(seed: [Capture]) -> AppEnvironment {
        AppEnvironment(
            captureStore: InMemoryCaptureStore(seed: seed),
            auth: MockAuthService(),
            bufferClient: MockBufferClient(),
            connectivity: MockConnectivityMonitor(),
            batchWindow: InMemoryBatchWindowSetting(window: BatchWindow.off)
        )
    }
}
