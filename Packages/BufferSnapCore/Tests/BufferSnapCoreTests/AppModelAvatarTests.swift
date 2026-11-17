import BufferSnapCore
import Foundation
import Testing

/// The account's picture: downloaded only when its URL changes, saved for a relaunch with no network, kept when a
/// download fails, and deleted wherever the account is forgotten.
@MainActor
struct AppModelAvatarTests {
    private let clock = ManualNow()
    private let accountStore = InMemoryAccountStore()
    private let avatarStore = InMemoryAvatarImageStore()

    private func model(
        auth: any AuthService = StubAuthService(hasSavedSession: true),
        ideas: any IdeasAtSignIn = NoIdeasAtSignIn(),
        accounts: any AccountSource,
        avatars: any AvatarDownloader = StubAvatarDownloader()
    ) -> AppModel {
        AppModel(
            auth: auth,
            ideas: ideas,
            accounts: accounts,
            accountStore: accountStore,
            avatars: avatars,
            avatarStore: avatarStore
        ) { [clock] in clock.now }
    }

    /// Ada, saved as of `minutesAgo`, with her picture `picture` saved too.
    private func saveAda(picture: String, minutesAgo: Double = 0) {
        let fetchedAt = clock.now.addingTimeInterval(-minutesAgo * 60)
        accountStore.save(SavedAccount(account: .ada(picture: picture), fetchedAt: fetchedAt))
        avatarStore.save(AvatarFixtures.png, from: AvatarFixtures.url(picture))
    }

    // MARK: - Downloading

    @Test func aSignInShowsAndSavesThePicture() async {
        let avatars = StubAvatarDownloader(.success(AvatarFixtures.png))
        let model = model(
            auth: StubAuthService(),
            accounts: StubAccountSource(.success(.ada(picture: "ada"))),
            avatars: avatars
        )

        await model.signIn()

        #expect(model.avatarImage == AvatarFixtures.png)
        #expect(avatarStore.holds(AvatarFixtures.url("ada")))
        #expect(await avatars.requested == [AvatarFixtures.url("ada")])
    }

    /// The question comes as soon as Buffer says who it is. Initials show while the picture loads.
    @Test func theQuestionDoesntWaitForThePicture() async {
        let avatars = StubAvatarDownloader()
        let model = model(
            auth: StubAuthService(),
            ideas: StubIdeasAtSignIn(heldIdeas: 2),
            accounts: StubAccountSource(.success(.ada(picture: "ada"))),
            avatars: avatars
        )
        await avatars.holdNextDownload()

        async let signIn: Void = model.signIn()
        await avatars.waitForHeldDownload()
        #expect(model.ideasToConfirm == 2)
        #expect(model.account?.initials == "AL")
        #expect(model.avatarImage == nil)
        await avatars.releaseDownload()
        await signIn

        #expect(model.avatarImage == AvatarFixtures.png)
    }

    @Test func thePictureShowsAfterARelaunchWithNoNetwork() async {
        saveAda(picture: "ada", minutesAgo: 120)
        let avatars = StubAvatarDownloader(.failure(.connection(code: -1009)))
        let model = model(accounts: StubAccountSource(.failure(.connection)), avatars: avatars)
        #expect(model.avatarImage == AvatarFixtures.png)

        await model.checkSession()

        #expect(model.avatarImage == AvatarFixtures.png)
        #expect(await avatars.requested.isEmpty)
    }

    /// Asking Buffer again every hour doesn't download the same picture again.
    @Test func theSamePictureIsntDownloadedAgain() async {
        saveAda(picture: "ada", minutesAgo: 120)
        let accounts = StubAccountSource(.success(.ada(picture: "ada")))
        let avatars = StubAvatarDownloader()
        let model = model(accounts: accounts, avatars: avatars)

        await model.checkSession()
        clock.advance(minutes: 61)
        await model.checkSession()

        #expect(await accounts.fetchCount == 2)
        #expect(await avatars.requested.isEmpty)
        #expect(model.avatarImage == AvatarFixtures.png)
    }

    @Test func aNewPictureReplacesTheOldOne() async {
        saveAda(picture: "ada", minutesAgo: 120)
        let avatars = StubAvatarDownloader(.success(AvatarFixtures.otherPNG))
        let model = model(accounts: StubAccountSource(.success(.ada(picture: "ada-new"))), avatars: avatars)

        await model.checkSession()

        #expect(await avatars.requested == [AvatarFixtures.url("ada-new")])
        #expect(model.avatarImage == AvatarFixtures.otherPNG)
        #expect(avatarStore.holds(AvatarFixtures.url("ada-new")))
        #expect(!avatarStore.holds(AvatarFixtures.url("ada")))
    }

    /// A failed download, or one that isn't an image, keeps the picture that was showing, and the session.
    @Test(arguments: [AvatarError.connection(code: -1001), .status(403), .notAnImage])
    func aFailedDownloadKeepsTheOldPicture(error: AvatarError) async {
        saveAda(picture: "ada", minutesAgo: 120)
        let avatars = StubAvatarDownloader(.failure(error))
        let model = model(accounts: StubAccountSource(.success(.ada(picture: "ada-new"))), avatars: avatars)

        await model.checkSession()

        #expect(model.isSignedIn)
        #expect(model.avatarImage == AvatarFixtures.png)
        #expect(avatarStore.holds(AvatarFixtures.url("ada")))
    }

    /// Without an old picture, initials stay.
    @Test func aFailedFirstDownloadShowsInitials() async {
        let model = model(
            auth: StubAuthService(),
            accounts: StubAccountSource(.success(.ada(picture: "ada"))),
            avatars: StubAvatarDownloader(.failure(.notAnImage))
        )

        await model.signIn()

        #expect(model.isSignedIn)
        #expect(model.avatarImage == nil)
        #expect(model.account?.initials == "AL")
    }

    /// Each URL is asked for once per launch, even if it failed.
    @Test func aFailedURLIsntAskedForAgain() async {
        let accounts = StubAccountSource(.success(.ada(picture: "ada")))
        let avatars = StubAvatarDownloader(.failure(.status(500)), .success(AvatarFixtures.png))
        let model = model(auth: StubAuthService(), accounts: accounts, avatars: avatars)

        await model.signIn()
        await model.checkSession()
        clock.advance(minutes: 61)
        await model.checkSession()

        #expect(await accounts.fetchCount == 2)
        #expect(await avatars.requested == [AvatarFixtures.url("ada")])
        #expect(model.avatarImage == nil)
    }

    /// An account whose picture Buffer took away, or moved off its bucket, shows initials again.
    @Test func anAccountWithoutAPictureLosesTheSavedOne() async {
        saveAda(picture: "ada", minutesAgo: 120)
        let elsewhere = BufferAccount(
            name: "Ada Lovelace",
            email: "ada@example.com",
            avatarURL: URL(string: "https://evil.example/ada.png")
        )
        let avatars = StubAvatarDownloader()
        let model = model(accounts: StubAccountSource(.success(elsewhere)), avatars: avatars)

        await model.checkSession()

        #expect(model.avatarImage == nil)
        #expect(avatarStore.load() == nil)
        #expect(await avatars.requested.isEmpty)
    }

    // MARK: - Forgetting

    @Test func signingOutDeletesThePicture() async {
        saveAda(picture: "ada")
        let model = model(accounts: StubAccountSource())

        await model.signOut()

        #expect(model.avatarImage == nil)
        #expect(avatarStore.load() == nil)
    }

    @Test func aFailedSignOutStillDeletesThePicture() async {
        saveAda(picture: "ada")
        let model = model(
            auth: StubAuthService(hasSavedSession: true, signOutError: AuthError.storage),
            accounts: StubAccountSource()
        )

        await model.signOut()

        #expect(model.avatarImage == nil)
        #expect(avatarStore.load() == nil)
    }

    @Test func aSessionBufferEndedDeletesThePicture() async {
        saveAda(picture: "ada")
        let model = model(
            auth: StubAuthService(hasSavedSession: true, tokenError: AuthError.sessionExpired),
            accounts: StubAccountSource()
        )

        await model.checkSession()

        #expect(model.avatarImage == nil)
        #expect(avatarStore.load() == nil)
    }

    /// The next sign-in may be someone else, so a picture left behind goes before anything is shown.
    @Test func aSignInDeletesAPictureLeftBehind() async {
        avatarStore.save(AvatarFixtures.png, from: AvatarFixtures.url("ada"))
        let model = model(
            auth: StubAuthService(),
            accounts: StubAccountSource(.failure(.connection)),
            avatars: StubAvatarDownloader()
        )

        await model.signIn()

        #expect(model.avatarImage == nil)
        #expect(avatarStore.load() == nil)
    }

    @Test func switchingAccountsShowsOnlyTheNewPicture() async {
        let accounts = StubAccountSource(.success(.ada(picture: "ada")), .success(.grace(picture: "grace")))
        let avatars = StubAvatarDownloader(.success(AvatarFixtures.png), .success(AvatarFixtures.otherPNG))
        let model = model(auth: StubAuthService(), accounts: accounts, avatars: avatars)
        await model.signIn()
        #expect(model.avatarImage == AvatarFixtures.png)

        await model.signOut()
        #expect(model.avatarImage == nil)
        await model.signIn()

        #expect(model.avatarImage == AvatarFixtures.otherPNG)
        #expect(avatarStore.holds(AvatarFixtures.url("grace")))
        #expect(!avatarStore.holds(AvatarFixtures.url("ada")))
    }

    /// A download that finishes after a sign-out was for the account that's gone.
    @Test func aDownloadThatEndsAfterASignOutShowsNothing() async {
        let avatars = StubAvatarDownloader()
        let model = model(
            auth: StubAuthService(),
            accounts: StubAccountSource(.success(.ada(picture: "ada"))),
            avatars: avatars
        )
        await avatars.holdNextDownload()

        async let signIn: Void = model.signIn()
        await avatars.waitForHeldDownload()
        await model.signOut()
        await avatars.releaseDownload()
        await signIn

        #expect(model.avatarImage == nil)
        #expect(avatarStore.load() == nil)
    }

    /// A slow download of the old picture doesn't overwrite the account's new one, or bring a picture back.
    @Test(arguments: [AvatarFixtures.url("ada-new"), nil] as [URL?])
    func aDownloadThatEndsAfterThePictureChangedShowsNothing(newPicture: URL?) async {
        let newAccount = BufferAccount(name: "Ada Lovelace", email: "ada@example.com", avatarURL: newPicture)
        let accounts = StubAccountSource(.success(.ada(picture: "ada")), .success(newAccount))
        // The first answer goes to the second request, as the first is held until after it.
        let avatars = StubAvatarDownloader(.success(AvatarFixtures.png), .success(AvatarFixtures.otherPNG))
        let model = model(auth: StubAuthService(), accounts: accounts, avatars: avatars)
        await avatars.holdNextDownload()

        async let signIn: Void = model.signIn()
        await avatars.waitForHeldDownload()
        clock.advance(minutes: 61)
        await model.checkSession()
        await avatars.releaseDownload()
        await signIn

        if let newPicture {
            #expect(model.avatarImage == AvatarFixtures.png)
            #expect(avatarStore.holds(newPicture))
        } else {
            #expect(model.avatarImage == nil)
            #expect(avatarStore.load() == nil)
        }
        #expect(!avatarStore.holds(AvatarFixtures.url("ada")))
    }
}
