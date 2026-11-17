import BufferSnapCore
import Testing

/// A launch whose Keychain read failed starts signed out. Coming to the foreground looks again, unless someone or
/// Buffer has ended a session since.
@MainActor
struct AppModelMissedSessionTests {
    @Test func aSessionTheLaunchCouldntReadSignsInAtTheNextForeground() async {
        let auth = StubAuthService()
        let ideas = StubIdeasAtSignIn()
        let model = AppModel(auth: auth, ideas: ideas)
        #expect(!model.isSignedIn)

        auth.setHasSavedSession(true)
        await model.checkSession()

        #expect(model.isSignedIn)
        #expect(model.signInPrompt == nil)
        #expect(await ideas.releaseCount == 0)
    }

    /// The row's notice is about being signed out, which they no longer are.
    @Test func findingTheSessionClearsTheNotice() async {
        let auth = StubAuthService(signInError: AuthError.cancelled)
        let model = AppModel(auth: auth)
        await model.signIn()
        #expect(model.signInNotice == .cancelled)

        auth.setHasSavedSession(true)
        await model.checkSession()

        #expect(model.isSignedIn)
        #expect(model.signInNotice == nil)
    }

    /// The session it finds is checked like any other, so one Buffer has ended asks in the list.
    @Test func aFoundSessionBufferEndedAsksInTheList() async {
        let auth = StubAuthService(tokenError: AuthError.sessionExpired)
        let model = AppModel(auth: auth)

        auth.setHasSavedSession(true)
        await model.checkSession()

        #expect(!model.isSignedIn)
        #expect(model.signInNotice == .sessionEnded)
    }

    /// The tokens a failed sign-out left behind are still saved, but the person asked to be signed out.
    @Test func tokensAFailedSignOutLeftDontSignBackIn() async {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true, signOutError: AuthError.storage))
        await model.signOut()

        await model.checkSession()

        #expect(!model.isSignedIn)
        #expect(model.signInNotice == .signOutFailed)
    }

    /// A session Buffer ended whose tokens couldn't be removed is still saved, but it's over.
    @Test func aSessionBufferEndedIsntFoundAgain() async {
        let model = AppModel(auth: StubAuthService(hasSavedSession: true, tokenError: AuthError.sessionExpired))
        await model.checkSession()
        #expect(model.signInNotice == .sessionEnded)

        await model.checkSession()

        #expect(!model.isSignedIn)
        #expect(model.signInNotice == .sessionEnded)
    }
}
