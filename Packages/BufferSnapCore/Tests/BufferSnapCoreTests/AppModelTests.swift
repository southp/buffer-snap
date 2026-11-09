import BufferSnapCore
import Testing

@MainActor
struct AppModelTests {
    /// The list is the first screen, whether or not anyone is signed in.
    @Test func startsOnTheListSignedOut() {
        let model = AppModel(auth: MockAuthService())

        #expect(model.route == .captureList)
        #expect(!model.isSignedIn)
    }

    /// The state is right as soon as the model exists, so no frame shows offline mode to someone who's signed in.
    @Test func aSavedSessionStartsSignedIn() {
        let model = AppModel(auth: MockAuthService(hasSavedSession: true))

        #expect(model.route == .captureList)
        #expect(model.isSignedIn)
    }

    /// What #41's cold launch relies on: asking for either screen right after launch isn't refused.
    @Test func navigatingWorksImmediatelyWhetherOrNotSignedIn() {
        let signedIn = AppModel(auth: MockAuthService(hasSavedSession: true))
        let signedOut = AppModel(auth: MockAuthService())

        signedIn.showCapture()
        signedOut.showCapture()
        #expect(signedIn.route == .capture)
        #expect(signedOut.route == .capture)

        signedOut.showCaptureList()
        #expect(signedOut.route == .captureList)
    }

    @Test func signingInStaysWhereItIsAndSaysNothing() async {
        let model = AppModel(auth: MockAuthService())

        await model.signIn()

        #expect(model.route == .captureList)
        #expect(model.isSignedIn)
        #expect(model.signInNotice == nil)
        #expect(model.signInPrompt == nil)
    }

    @Test func theSignInRowShowsWhileSignedOutAndGoesAway() async {
        let model = AppModel(auth: MockAuthService())
        #expect(model.signInPrompt == AppModel.SignInPrompt(notice: nil, isSigningIn: false))

        await model.signIn()

        #expect(model.signInPrompt == nil)
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

        #expect(!model.isSignedIn)
        #expect(model.signInNotice == notice)
        #expect(!model.isSigningIn)
    }

    @Test func anUnexpectedSignInErrorStillSaysSomething() async {
        let model = AppModel(auth: StubAuthService(signInError: TestError()))

        await model.signIn()

        #expect(!model.isSignedIn)
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
        #expect(model.isSignedIn)
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
        #expect(model.isSignedIn)
    }

    /// Signing out stays on the list, wherever the person was.
    @Test func signingOutStaysOnTheList() async {
        let model = AppModel(auth: MockAuthService(hasSavedSession: true))

        await model.signOut()

        #expect(model.route == .captureList)
        #expect(!model.isSignedIn)
        #expect(model.signInNotice == nil)
    }

    @Test func signingOutOnTheCaptureScreenLeavesItWhereItIs() async {
        let model = AppModel(auth: MockAuthService(hasSavedSession: true))
        model.showCapture()

        await model.signOut()

        #expect(model.route == .capture)
        #expect(!model.isSignedIn)
    }

    /// The tokens are still there, so a relaunch would sign back in. The user has to hear about that.
    @Test func failingToRemoveTheTokensSaysSo() async {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true, signOutError: AuthError.storage))

        await model.signOut()

        #expect(!model.isSignedIn)
        #expect(model.signInNotice == .signOutFailed)
    }

    @Test func aSessionThatStillWorksChangesNothing() async {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true))
        model.showCaptureList()

        await model.checkSession()

        #expect(model.isSignedIn)
        #expect(model.signInNotice == nil)
    }

    /// Offline at launch, or Buffer having a bad moment, must never sign anyone out.
    @Test(arguments: [AuthError.network, .server, .storage])
    func aFailureThatCanPassKeepsTheUserSignedIn(error: AuthError) async {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true, tokenError: error))

        await model.checkSession()

        #expect(model.isSignedIn)
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

    /// A session Buffer ended leaves the person where they were and asks in the list, with no full-screen takeover.
    @Test(arguments: [AuthError.sessionExpired, .notSignedIn])
    func losingTheSessionStaysPutAndAsksInTheList(error: AuthError) async {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true, tokenError: error))
        model.showCapture()

        await model.checkSession()

        #expect(model.route == .capture)
        #expect(!model.isSignedIn)
        #expect(model.signInNotice == .sessionEnded)
        #expect(model.signInPrompt == AppModel.SignInPrompt(notice: .sessionEnded, isSigningIn: false))
    }

    @Test func checkingWhileSignedOutDoesNothing() async {
        let auth = StubAuthService(tokenError: AuthError.sessionExpired)
        let model = AppModel(auth: auth)

        await model.checkSession()

        #expect(!model.isSignedIn)
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

        #expect(!model.isSignedIn)
        #expect(model.signInNotice == nil)
    }

    /// A cold launch from a control, whichever comes first: the intent, or a sign-in finishing.
    @Test func askingForCaptureDuringASignInSticks() async {
        let auth = HeldAuthService()
        let model = AppModel(auth: auth)
        let signIn = Task {
            await model.signIn()
        }
        await auth.waitForSignIn()

        model.showCapture()

        await auth.finishSignIn()
        await signIn.value
        #expect(model.route == .capture)
        #expect(model.isSignedIn)
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
