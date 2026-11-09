import BufferSnapCore
import Testing

@MainActor
struct AppModelTests {
    @Test func startsSignedOut() {
        let model = AppModel(auth: MockAuthService())

        #expect(model.route == .signedOut)
    }

    /// The route is right as soon as the model exists, so no frame shows sign-in to someone who's signed in.
    @Test func aSavedSessionStartsOnTheCaptureScreen() {
        let model = AppModel(auth: MockAuthService(hasSavedSession: true))

        #expect(model.route == .capture)
    }

    /// What #41's cold launch relies on: opening the list or the capture screen right after launch isn't refused.
    @Test func aSavedSessionCanNavigateImmediately() {
        let model = AppModel(auth: MockAuthService(hasSavedSession: true))

        model.showCaptureList()
        #expect(model.route == .captureList)

        model.showCapture()
        #expect(model.route == .capture)
    }

    @Test func signInRoutesToTheCaptureScreen() async {
        let model = AppModel(auth: MockAuthService())

        await model.signIn()

        #expect(model.route == .capture)
        #expect(model.signInNotice == nil)
    }

    @Test func captureListAndCaptureScreenAreOneStepApart() async {
        let model = AppModel(auth: MockAuthService())
        await model.signIn()

        model.showCaptureList()
        #expect(model.route == .captureList)

        model.showCapture()
        #expect(model.route == .capture)
    }

    @Test func nothingLeavesSignedOutButSigningIn() {
        let model = AppModel(auth: MockAuthService())

        model.showCaptureList()
        #expect(model.route == .signedOut)

        model.showCapture()
        #expect(model.route == .signedOut)
    }

    @Test(arguments: [
        (AuthError.cancelled, AppModel.SignInNotice.cancelled),
        (.denied, .denied),
        (.network, .unreachable),
        (.server, .failed),
        (.authorizationFailed, .failed),
        (.storage, .failed),
    ])
    func failedSignInStaysSignedOutAndSaysWhy(error: AuthError, notice: AppModel.SignInNotice) async {
        let model = AppModel(auth: StubAuthService(signInError: error))

        await model.signIn()

        #expect(model.route == .signedOut)
        #expect(model.signInNotice == notice)
        #expect(!model.isSigningIn)
    }

    @Test func anUnexpectedSignInErrorStillSaysSomething() async {
        let model = AppModel(auth: StubAuthService(signInError: TestError()))

        await model.signIn()

        #expect(model.route == .signedOut)
        #expect(model.signInNotice == .failed)
    }

    @Test func tryingAgainClearsTheNotice() async {
        let auth = ControllableSignInAuthService()
        let model = AppModel(auth: auth)
        await auth.failNextSignIn(with: AuthError.cancelled)
        await model.signIn()
        #expect(model.signInNotice == .cancelled)

        await model.signIn()

        #expect(model.signInNotice == nil)
        #expect(model.route == .capture)
    }

    /// A second tap can't start a second web session while the first is open.
    @Test func aSecondTapDuringSignInDoesNothing() async {
        let auth = ControllableSignInAuthService()
        let model = AppModel(auth: auth)
        await auth.holdNextSignIn()

        async let first: Void = model.signIn()
        await auth.waitForHeldSignIn()
        #expect(model.isSigningIn)
        await model.signIn()
        await auth.releaseSignIn()
        await first

        #expect(await auth.signInCount == 1)
        #expect(model.route == .capture)
    }

    @Test func preparationRunsBeforeTheSignInStarts() async {
        let auth = ControllableSignInAuthService()
        let signInsAtPreparation = RecordedValue()
        let model = AppModel(
            auth: auth,
            prepareForSignIn: {
                await signInsAtPreparation.set(await auth.signInCount)
            }
        )

        await model.signIn()

        #expect(await signInsAtPreparation.value == 0)
        #expect(await auth.signInCount == 1)
    }

    /// If the captures can't be held, signing in could send them to whoever signs in, so it mustn't go ahead.
    @Test func aFailedPreparationStopsTheSignIn() async {
        let auth = ControllableSignInAuthService()
        let model = AppModel(auth: auth, prepareForSignIn: { throw TestError() })

        await model.signIn()

        #expect(await auth.signInCount == 0)
        #expect(model.route == .signedOut)
        #expect(model.signInNotice == .failed)
    }

    /// The whole of it: someone signs out with a capture pending, and whoever signs in next doesn't get it by itself.
    @Test func aPendingCaptureDoesntFollowASignOutToTheNextAccount() async throws {
        let capture = Capture.text("Their idea")
        let store = InMemoryCaptureStore(seed: [capture])
        let buffer = MockBufferClient()
        let auth = MockAuthService(hasSavedSession: true)
        let queue = SubmissionQueue(store: store, auth: auth, client: buffer)
        let model = AppModel(auth: auth, prepareForSignIn: { try await queue.holdPendingCaptures() })

        await model.signOut()
        await model.signIn()
        await queue.run()

        #expect(await buffer.createdIdeas.isEmpty)
        #expect(await store.all().map(\.status) == [.failed])

        try await queue.resend(capture.id)
        await queue.run()
        #expect(await buffer.createdIdeas == ["Their idea"])
    }

    /// A capture made after signing in goes as usual.
    @Test func aCaptureMadeAfterSigningInStillGoes() async throws {
        let store = InMemoryCaptureStore()
        let buffer = MockBufferClient()
        let auth = MockAuthService()
        let queue = SubmissionQueue(store: store, auth: auth, client: buffer)
        let model = AppModel(auth: auth, prepareForSignIn: { try await queue.holdPendingCaptures() })

        await model.signIn()
        try await store.add(.text("A new idea"))
        await queue.run()

        #expect(await buffer.createdIdeas == ["A new idea"])
    }

    @Test func signOutReturnsToSignIn() async {
        let model = AppModel(auth: MockAuthService(hasSavedSession: true))

        await model.signOut()

        #expect(model.route == .signedOut)
        #expect(model.signInNotice == nil)
    }

    @Test func signOutFromTheCaptureListReturnsToSignIn() async {
        let model = AppModel(auth: MockAuthService(hasSavedSession: true))
        model.showCaptureList()

        await model.signOut()

        #expect(model.route == .signedOut)
    }

    /// The tokens are still there, so a relaunch would sign back in. The user has to hear about that.
    @Test func failingToRemoveTheTokensSaysSo() async {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true, signOutError: AuthError.storage))

        await model.signOut()

        #expect(model.route == .signedOut)
        #expect(model.signInNotice == .signOutFailed)
    }

    @Test func aSessionThatStillWorksChangesNothing() async {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true))
        model.showCaptureList()

        await model.checkSession()

        #expect(model.route == .captureList)
        #expect(model.signInNotice == nil)
    }

    /// Offline at launch, or Buffer having a bad moment, must never sign anyone out.
    @Test(arguments: [AuthError.network, .server, .storage])
    func aFailureThatCanPassKeepsTheUserSignedIn(error: AuthError) async {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true, tokenError: error))

        await model.checkSession()

        #expect(model.route == .capture)
        #expect(model.signInNotice == nil)
    }

    @Test func theLiveActivitiesNoticeShowsUntilDismissed() {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true))
        #expect(!model.isShowingLiveActivitiesNotice)

        model.showLiveActivitiesNotice()
        #expect(model.isShowingLiveActivitiesNotice)

        model.dismissLiveActivitiesNotice()
        #expect(!model.isShowingLiveActivitiesNotice)
    }

    @Test(arguments: [AuthError.sessionExpired, .notSignedIn])
    func losingTheSessionReturnsToSignInAndSaysWhy(error: AuthError) async {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true, tokenError: error))

        await model.checkSession()

        #expect(model.route == .signedOut)
        #expect(model.signInNotice == .sessionEnded)
    }

    @Test func checkingWhileSignedOutDoesNothing() async {
        let auth = StubAuthService(tokenError: AuthError.sessionExpired)
        let model = AppModel(auth: auth)

        await model.checkSession()

        #expect(model.route == .signedOut)
        #expect(model.signInNotice == nil)
    }

    /// A check still in flight when the user signs out finds no session, but that's not a session ending on them.
    @Test func signingOutDuringACheckShowsNoNotice() async {
        let auth = StubAuthService(hasSavedSession: true, tokenError: AuthError.notSignedIn)
        let model = AppModel(auth: auth)
        await auth.setOnValidAccessToken {
            await model.signOut()
        }

        await model.checkSession()

        #expect(model.route == .signedOut)
        #expect(model.signInNotice == nil)
    }

    @Test func showCaptureStaysOnTheCaptureScreen() async {
        let model = AppModel(auth: MockAuthService())
        await model.signIn()

        model.showCapture()

        #expect(model.route == .capture)
    }

    /// A cold launch from a control: the intent can run before the app is past sign-in, and must still end on capture.
    @Test func askingForCaptureWhileSigningInStillEndsOnCapture() async {
        let auth = HeldAuthService()
        let model = AppModel(auth: auth)
        let signIn = Task {
            await model.signIn()
        }
        await auth.waitForSignIn()

        model.showCapture()
        #expect(model.route == .signedOut)

        await auth.finishSignIn()
        await signIn.value
        #expect(model.route == .capture)
    }

    @Test func askingForCaptureBeforeSigningInStillEndsOnCapture() async {
        let model = AppModel(auth: MockAuthService())

        model.showCapture()
        await model.signIn()

        #expect(model.route == .capture)
    }
}

/// An `AuthService` whose sign-in waits until the test lets it finish.
private actor HeldAuthService: AuthService {
    private var started: CheckedContinuation<Void, Never>?
    private var finish: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    nonisolated func hasSavedSession() -> Bool {
        false
    }

    func signIn() async throws {
        hasStarted = true
        started?.resume()
        await withCheckedContinuation { finish = $0 }
    }

    func signOut() async throws {}

    func validAccessToken() async throws -> String {
        "token"
    }

    func accessTokenRejected(_ token: String) async {}

    func waitForSignIn() async {
        if !hasStarted {
            await withCheckedContinuation { started = $0 }
        }
    }

    func finishSignIn() {
        finish?.resume()
    }
}

private actor RecordedValue {
    private(set) var value: Int?

    func set(_ value: Int) {
        self.value = value
    }
}
