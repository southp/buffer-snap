import BufferSnapCore
import Testing

@MainActor
struct AppModelTests {
    @Test func startsSignedOutWithoutASavedSession() {
        let model = AppModel(auth: MockAuthService())

        #expect(!model.isSignedIn)
    }

    /// The state is right as soon as the model exists, so no frame shows offline mode to someone who's signed in.
    @Test func aSavedSessionStartsSignedIn() {
        let model = AppModel(auth: MockAuthService(hasSavedSession: true))

        #expect(model.isSignedIn)
    }

    @Test func signingInSaysNothing() async {
        let model = AppModel(auth: MockAuthService())

        await model.signIn()

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

    @Test func signingOutSaysNothing() async {
        let model = AppModel(auth: MockAuthService(hasSavedSession: true))

        await model.signOut()

        #expect(!model.isSignedIn)
        #expect(model.signInNotice == nil)
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

    /// A press that opened the app says why, until the alert is dismissed. An undecided permission says nothing: the
    /// app asks for it as it comes to the foreground.
    @Test(arguments: [
        (HandsFreeDictationSession.NeedsTheAppReason.liveActivitiesOff, Optional(DictationNotice.liveActivitiesOff)),
        (.permission(.microphoneDenied), .microphoneOff),
        (.permission(.speechRecognitionDenied), .speechRecognitionOff),
        (.permission(.restricted), .restricted),
        (.permission(.undetermined), nil),
    ])
    func aPressThatOpenedTheAppSaysWhy(reason: HandsFreeDictationSession.NeedsTheAppReason, notice: DictationNotice?) {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true))
        #expect(model.dictationNotice == nil)

        model.showDictationNotice(for: reason)
        #expect(model.dictationNotice == notice)

        model.dismissDictationNotice()
        #expect(model.dictationNotice == nil)
    }

    /// Settings has no switch for a restricted iPhone, so only the other notices offer it.
    @Test func onlyARestrictedPermissionCantBeFixedInSettings() {
        #expect(DictationNotice.liveActivitiesOff.canOpenSettings)
        #expect(DictationNotice.microphoneOff.canOpenSettings)
        #expect(DictationNotice.speechRecognitionOff.canOpenSettings)
        #expect(!DictationNotice.restricted.canOpenSettings)
    }

    /// A session Buffer ended asks in the list, with no full-screen takeover.
    @Test(arguments: [AuthError.sessionExpired, .notSignedIn])
    func losingTheSessionAsksInTheList(error: AuthError) async {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true, tokenError: error))

        await model.checkSession()

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
}
