import BufferSnapCore
import Testing

/// What happens to waiting captures around a sign-in: `docs/decisions/68-ideas-at-sign-in.md`.
@MainActor
struct AppModelSignInIdeasTests {
    @Test func holdingHappensBeforeTheSignInStarts() async {
        let auth = ControllableSignInAuthService()
        let ideas = StubIdeasAtSignIn()
        let model = AppModel(auth: auth, ideas: ideas)
        await ideas.setOnHold {
            await ideas.recordSignInsAtHold(await auth.signInCount)
        }

        await model.signIn()

        #expect(await ideas.signInsAtHold.first == 0)
        #expect(await auth.signInCount == 1)
    }

    /// If the captures can't be held, signing in could send them to whoever signs in, so it mustn't go ahead.
    @Test func aFailedHoldStopsTheSignIn() async {
        let auth = ControllableSignInAuthService()
        let model = AppModel(auth: auth, ideas: StubIdeasAtSignIn(holdError: TestError()))

        await model.signIn()

        #expect(await auth.signInCount == 0)
        #expect(model.route == .signedOut)
        #expect(model.signInNotice == .failed)
    }

    /// Sign-in asks once, after it's done, about everything that was waiting.
    @Test func aSignInAsksAboutWhatIsHeld() async {
        let ideas = StubIdeasAtSignIn(heldIdeas: 3)
        let model = AppModel(auth: MockAuthService(), ideas: ideas)

        await model.signIn()

        #expect(model.ideasToConfirm == 3)
    }

    @Test func nothingHeldAsksNothing() async {
        let model = AppModel(auth: MockAuthService(), ideas: StubIdeasAtSignIn())

        await model.signIn()

        #expect(model.ideasToConfirm == nil)
    }

    /// Something saved while Buffer's page was open waits with the rest, and doesn't slip through unasked.
    @Test func whatsSavedDuringTheSignInIsHeldToo() async {
        let ideas = StubIdeasAtSignIn()
        let model = AppModel(auth: MockAuthService(), ideas: ideas)

        await model.signIn()

        #expect(await ideas.holdCount == 2)
    }

    @Test func sayingYesSendsWhatWasHeld() async {
        let ideas = StubIdeasAtSignIn(heldIdeas: 2)
        let model = AppModel(auth: MockAuthService(), ideas: ideas)
        await model.signIn()

        await model.sendHeldIdeas()

        #expect(await ideas.sendCount == 1)
        #expect(model.ideasToConfirm == nil)
    }

    /// Declining loses nothing: what was held stays held, and the question doesn't come back.
    @Test func decliningSendsNothingAndAsksNoMore() async {
        let ideas = StubIdeasAtSignIn(heldIdeas: 2)
        let model = AppModel(auth: MockAuthService(), ideas: ideas)
        await model.signIn()

        model.keepHeldIdeas()

        #expect(await ideas.sendCount == 0)
        #expect(model.ideasToConfirm == nil)
    }

    /// A sign-in that didn't happen shouldn't leave anything looking failed.
    @Test func aFailedSignInReleasesWhatWasHeld() async {
        let ideas = StubIdeasAtSignIn(heldIdeas: 1)
        let model = AppModel(auth: StubAuthService(signInError: AuthError.cancelled), ideas: ideas)

        await model.signIn()

        #expect(await ideas.releaseCount == 1)
        #expect(model.ideasToConfirm == nil)
    }

    @Test func signingOutReleasesWhatWasHeld() async {
        let ideas = StubIdeasAtSignIn()
        let model = AppModel(auth: MockAuthService(hasSavedSession: true), ideas: ideas)

        await model.signOut()

        #expect(await ideas.releaseCount == 1)
    }

    @Test func aSessionBufferEndedReleasesWhatWasHeld() async {
        let ideas = StubIdeasAtSignIn()
        let auth = StubAuthService(hasSavedSession: true, tokenError: AuthError.sessionExpired)
        let model = AppModel(auth: auth, ideas: ideas)

        await model.checkSession()

        #expect(await ideas.releaseCount == 1)
    }

    /// A crash during a sign-in leaves captures held with nobody signed in, so the next foreground puts them back.
    @Test func aForegroundWhileSignedOutReleasesWhatACrashLeftHeld() async {
        let ideas = StubIdeasAtSignIn()
        let model = AppModel(auth: MockAuthService(), ideas: ideas)

        await model.checkSession()

        #expect(await ideas.releaseCount == 1)
    }

    /// Coming back from Buffer's page makes the scene active in the middle of a sign-in, which mustn't undo its hold.
    @Test func aForegroundDuringASignInDoesntReleaseAnything() async {
        let auth = ControllableSignInAuthService()
        let ideas = StubIdeasAtSignIn()
        let model = AppModel(auth: auth, ideas: ideas)
        await auth.holdNextSignIn()

        async let signIn: Void = model.signIn()
        await auth.waitForHeldSignIn()
        await model.checkSession()
        #expect(await ideas.releaseCount == 0)

        await auth.releaseSignIn()
        await signIn
    }

    /// The whole of it, through the real queue: someone signs out with a capture waiting, the next sign-in holds it
    /// and asks, and it only goes on a yes.
    @Test func aPendingCaptureDoesntFollowASignOutToTheNextAccount() async throws {
        let capture = Capture.text("Their idea")
        let store = InMemoryCaptureStore(seed: [capture])
        let buffer = MockBufferClient()
        let auth = MockAuthService(hasSavedSession: true)
        let queue = SubmissionQueue(store: store, auth: auth, client: buffer)
        let model = AppModel(auth: auth, ideas: queue)

        await model.signOut()
        await model.signIn()
        await queue.run()

        #expect(model.ideasToConfirm == 1)
        #expect(await buffer.createdIdeas.isEmpty)
        #expect(await store.all().map(\.status) == [.failed])

        await model.sendHeldIdeas()
        await queue.run()
        #expect(await buffer.createdIdeas == ["Their idea"])
        #expect(await store.all().map(\.status) == [.submitted])
    }

    /// Declining leaves it held, with Resend, and Resend still works: nothing is lost.
    @Test func declinedIdeasStayHeldAndCanStillBeSent() async throws {
        let capture = Capture.text("An idea")
        let store = InMemoryCaptureStore(seed: [capture])
        let buffer = MockBufferClient()
        let auth = MockAuthService()
        let queue = SubmissionQueue(store: store, auth: auth, client: buffer)
        let model = AppModel(auth: auth, ideas: queue)

        await model.signIn()
        model.keepHeldIdeas()
        await queue.run()

        #expect(await store.all().map(\.status) == [.failed])
        #expect(await store.all().map(\.failure) == [.heldAtSignIn])
        #expect(await buffer.createdIdeas.isEmpty)
        #expect(model.ideasToConfirm == nil)

        try await queue.resend(capture.id)
        await queue.run()
        #expect(await buffer.createdIdeas == ["An idea"])
    }

    /// A cancelled sign-in leaves everything waiting, as if it never happened, ready for the next one.
    @Test func aCancelledSignInPutsCapturesBackToWaiting() async throws {
        let store = InMemoryCaptureStore(seed: [.text("An idea")])
        let auth = StubAuthService(signInError: AuthError.cancelled)
        let queue = SubmissionQueue(store: store, auth: auth, client: MockBufferClient())
        let model = AppModel(auth: auth, ideas: queue)

        await model.signIn()

        #expect(await store.all().map(\.status) == [.pending])
        #expect(await store.all().map(\.failure) == [nil])
    }

    /// Everything captured while signed out reaches the account as decided: each batch once, and only after a yes.
    @Test func ideasCapturedSignedOutGoAsOneIdeaPerBatchAfterAYes() async throws {
        let first = Capture.text("Morning thought", at: 1)
        let second = Capture.text("Part two", at: 2)
        let later = Capture.text("Evening thought", at: 1000)
        let store = InMemoryCaptureStore(seed: [first, second, later])
        let buffer = MockBufferClient()
        let auth = MockAuthService()
        let queue = SubmissionQueue(
            store: store, auth: auth, client: buffer, planner: SubmissionPlanner { 300 }
        )
        let model = AppModel(auth: auth, ideas: queue)

        await model.signIn()
        #expect(model.ideasToConfirm == 2)
        await queue.run()
        #expect(await buffer.createdIdeas.isEmpty)

        await model.sendHeldIdeas()
        await queue.run()
        await queue.run()

        #expect(await buffer.createdIdeas.sorted() == ["Evening thought", "Morning thought\n\nPart two"])
        #expect(await store.all().map(\.status) == [.submitted, .submitted, .submitted])
    }

    /// A capture made after signing in goes as usual.
    @Test func aCaptureMadeAfterSigningInStillGoes() async throws {
        let store = InMemoryCaptureStore()
        let buffer = MockBufferClient()
        let auth = MockAuthService()
        let queue = SubmissionQueue(store: store, auth: auth, client: buffer)
        let model = AppModel(auth: auth, ideas: queue)

        await model.signIn()
        try await store.add(.text("A new idea"))
        await queue.run()

        #expect(await buffer.createdIdeas == ["A new idea"])
        #expect(model.ideasToConfirm == nil)
    }
}
