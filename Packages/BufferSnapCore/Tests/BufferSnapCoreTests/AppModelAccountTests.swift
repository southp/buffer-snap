import BufferSnapCore
import Foundation
import Testing

/// Which account is signed in: fetched at sign-in and then at most hourly, saved for a relaunch with no network, and
/// forgotten on sign-out and when another account may be signing in.
@MainActor
struct AppModelAccountTests {
    private let clock = ManualNow()
    private let store = InMemoryAccountStore()

    private func model(
        auth: any AuthService = StubAuthService(hasSavedSession: true),
        ideas: any IdeasAtSignIn = NoIdeasAtSignIn(),
        accounts: any AccountSource
    ) -> AppModel {
        AppModel(auth: auth, ideas: ideas, accounts: accounts, accountStore: store) { [clock] in clock.now }
    }

    private func saved(_ account: BufferAccount, minutesAgo: Double = 0) -> SavedAccount {
        SavedAccount(account: account, fetchedAt: clock.now.addingTimeInterval(-minutesAgo * 60))
    }

    // MARK: - Signing in

    @Test func aSignInShowsAndSavesTheAccount() async {
        let model = model(auth: StubAuthService(), accounts: StubAccountSource(.success(.ada)))

        await model.signIn()

        #expect(model.account == .ada)
        #expect(store.load() == saved(.ada))
    }

    /// The question names the account, so it waits for Buffer's answer.
    @Test func theQuestionAboutHeldIdeasComesWithTheAccount() async {
        let model = model(
            auth: StubAuthService(),
            ideas: StubIdeasAtSignIn(heldIdeas: 2),
            accounts: StubAccountSource(.success(.ada))
        )

        await model.signIn()

        #expect(model.ideasToConfirm == 2)
        #expect(model.account == .ada)
    }

    /// The name is only a label: without it, the sign-in still counts, and the question still comes.
    @Test func aFailedFetchAtSignInStillSignsIn() async {
        let model = model(
            auth: StubAuthService(),
            ideas: StubIdeasAtSignIn(heldIdeas: 1),
            accounts: StubAccountSource(.failure(.serverTrouble))
        )

        await model.signIn()

        #expect(model.isSignedIn)
        #expect(model.account == nil)
        #expect(model.ideasToConfirm == 1)
    }

    /// A sign-out whose Keychain delete failed can leave the last account saved. The next sign-in may be someone else.
    @Test func aSignInNeverShowsTheAccountSavedBeforeIt() async {
        store.save(saved(.ada))
        let model = model(auth: StubAuthService(), accounts: StubAccountSource(.failure(.connection)))

        await model.signIn()

        #expect(model.account == nil)
        #expect(store.load() == nil)
    }

    @Test func switchingAccountsShowsTheNewOne() async {
        let model = model(auth: StubAuthService(), accounts: StubAccountSource(.success(.ada), .success(.grace)))
        await model.signIn()
        #expect(model.account == .ada)

        await model.signOut()
        await model.signIn()

        #expect(model.account == .grace)
        #expect(store.load()?.account == .grace)
    }

    /// Signing out while Buffer is answering: the question isn't asked, as signing out released what was held.
    @Test func signingOutDuringTheFetchAsksNothing() async {
        let accounts = StubAccountSource(.success(.ada))
        let model = model(auth: StubAuthService(), ideas: StubIdeasAtSignIn(heldIdeas: 2), accounts: accounts)
        await accounts.holdNextFetch()

        async let signIn: Void = model.signIn()
        await accounts.waitForHeldFetch()
        await model.signOut()
        await accounts.releaseFetch()
        await signIn

        #expect(!model.isSignedIn)
        #expect(model.account == nil)
        #expect(model.ideasToConfirm == nil)
        #expect(store.load() == nil)
    }

    // MARK: - Relaunching

    @Test func theAccountShowsAfterARelaunchWithNoNetwork() async {
        store.save(saved(.ada, minutesAgo: 120))
        let model = model(accounts: StubAccountSource(.failure(.connection)))
        #expect(model.account == .ada)

        await model.checkSession()

        #expect(model.account == .ada)
    }

    /// Only a session found at launch shows the saved account: without one, nobody is signed in.
    @Test func signedOutAtLaunchShowsNoAccount() {
        store.save(saved(.ada))

        let model = model(auth: StubAuthService(), accounts: StubAccountSource())

        #expect(model.account == nil)
    }

    /// The session the launch couldn't read comes with the account saved for it.
    @Test func aSessionFoundAtTheForegroundShowsItsSavedAccount() async {
        store.save(saved(.ada, minutesAgo: 5))
        let auth = StubAuthService()
        let model = model(auth: auth, accounts: StubAccountSource(.failure(.connection)))

        auth.setHasSavedSession(true)
        await model.checkSession()

        #expect(model.account == .ada)
    }

    // MARK: - Asking again

    @Test func theForegroundAsksAtMostOnceAnHour() async {
        store.save(saved(.ada, minutesAgo: 30))
        let accounts = StubAccountSource(.success(.grace))
        let model = model(accounts: accounts)

        await model.checkSession()
        #expect(await accounts.fetchCount == 0)

        clock.advance(minutes: 30)
        await model.checkSession()
        #expect(await accounts.fetchCount == 1)
        #expect(model.account == .grace)

        clock.advance(minutes: 59)
        await model.checkSession()
        #expect(await accounts.fetchCount == 1)
    }

    /// A request that never left the iPhone, or that Buffer's rate limit kept back, costs nothing, so the next
    /// foreground tries again. The saved account stays meanwhile.
    @Test(arguments: [BufferError.connection, .rateLimited(retryAfter: 60)])
    func aRequestThatDidntReachBufferIsTriedAgain(error: BufferError) async {
        store.save(saved(.ada, minutesAgo: 90))
        let accounts = StubAccountSource(.failure(error), .success(.grace))
        let model = model(accounts: accounts)

        await model.checkSession()
        #expect(model.account == .ada)
        await model.checkSession()

        #expect(await accounts.fetchCount == 2)
        #expect(model.account == .grace)
    }

    /// Buffer answered, so asking again within the hour would only add to the rate limit.
    @Test func aFailureFromBufferWaitsTheHour() async {
        store.save(saved(.ada, minutesAgo: 90))
        let accounts = StubAccountSource(.failure(.serverTrouble), .success(.grace))
        let model = model(accounts: accounts)

        await model.checkSession()
        clock.advance(minutes: 10)
        await model.checkSession()

        #expect(await accounts.fetchCount == 1)
        #expect(model.account == .ada)
        #expect(model.isSignedIn)
    }

    /// The account query counts toward the limit on sending ideas, so it waits that limit out too.
    @Test func nothingIsAskedWhileBufferAsksToWait() async {
        let fixture = QueueFixture()
        let queue = fixture.makeQueue(store: InMemoryCaptureStore(seed: [.text("An idea")]))
        await fixture.server.failIdeas(.answer(.tooManyRequests(retryAfter: 60)))
        await queue.run()
        let model = model(accounts: queue)

        await model.checkSession()

        #expect(await fixture.server.accountRequests == 0)
        #expect(model.isSignedIn)
    }

    // MARK: - Forgetting

    @Test func signingOutForgetsTheAccount() async {
        store.save(saved(.ada))
        let model = model(accounts: StubAccountSource())

        await model.signOut()

        #expect(model.account == nil)
        #expect(store.load() == nil)
    }

    /// They asked to be signed out, even if the tokens couldn't be removed.
    @Test func aFailedSignOutStillForgetsTheAccount() async {
        store.save(saved(.ada))
        let model = model(
            auth: StubAuthService(hasSavedSession: true, signOutError: AuthError.storage),
            accounts: StubAccountSource()
        )

        await model.signOut()

        #expect(model.account == nil)
        #expect(store.load() == nil)
    }

    @Test func aSessionBufferEndedForgetsTheAccount() async {
        store.save(saved(.ada))
        let model = model(
            auth: StubAuthService(hasSavedSession: true, tokenError: AuthError.sessionExpired),
            accounts: StubAccountSource()
        )

        await model.checkSession()

        #expect(model.account == nil)
        #expect(store.load() == nil)
    }

    /// A fetch that finishes after a sign-out was for the account that's gone.
    @Test func aFetchThatEndsAfterASignOutShowsNothing() async {
        let accounts = StubAccountSource(.success(.ada))
        let model = model(accounts: accounts)
        await accounts.holdNextFetch()

        async let check: Void = model.checkSession()
        await accounts.waitForHeldFetch()
        await model.signOut()
        await accounts.releaseFetch()
        await check

        #expect(model.account == nil)
        #expect(store.load() == nil)
    }
}
