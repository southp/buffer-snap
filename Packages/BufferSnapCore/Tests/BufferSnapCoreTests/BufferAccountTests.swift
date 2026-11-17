import BufferSnapCore
import Foundation
import Testing

/// Who the account is: what the app reads from Buffer, and the initials the chip shows.
struct BufferAccountTests {
    @Test(arguments: [
        ("Ada Lovelace", "AL"),
        ("ada lovelace", "AL"),
        ("Ada King Lovelace", "AL"),
        ("  Ada   Lovelace  ", "AL"),
        ("Cher", "C"),
        ("Émile Zola", "ÉZ"),
        ("山田太郎", "山"),
    ])
    func initialsComeFromTheFirstAndLastWords(name: String, initials: String) {
        #expect(BufferAccount(name: name, email: nil).initials == initials)
    }

    /// The chip shows the `person` glyph instead, and the question says "this account".
    @Test(arguments: [nil, "", "   "] as [String?])
    func noNameMeansNoInitialsAndNoName(name: String?) {
        let account = BufferAccount(name: name, email: "ada@example.com")

        #expect(account.initials == nil)
        #expect(account.displayName == nil)
    }

    @Test func theNameIsShownTrimmed() {
        #expect(BufferAccount(name: " Ada Lovelace\n", email: nil).displayName == "Ada Lovelace")
    }

    @Test func theAccountComesFromBuffersAccountQuery() async throws {
        let avatar = "https://buffer-account-avatars-bucket.s3.amazonaws.com/example/ada.png"
        let body = #"{"data":{"account":{"name":"Ada Lovelace","email":"ada@example.com","avatar":"\#(avatar)"}}}"#
        let transport = CannedTransport(.init(body: body))
        let client = GraphQLBufferClient(transport: transport)

        let account = try await client.account(accessToken: "token")

        let expected = BufferAccount(name: "Ada Lovelace", email: "ada@example.com", avatarURL: URL(string: avatar))
        #expect(account == expected)
        #expect(account.avatarURL?.absoluteString == avatar)
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        let sent = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        #expect(sent["query"] as? String == "query Account { account { name email avatar } }")
    }

    /// `Account.name` is nullable in Buffer's schema.
    @Test func anAccountWithoutANameStillComesBack() async throws {
        let body = #"{"data":{"account":{"name":null,"email":"ada@example.com"}}}"#
        let client = GraphQLBufferClient(transport: CannedTransport(.init(body: body)))

        #expect(try await client.account(accessToken: "token") == BufferAccount(name: nil, email: "ada@example.com"))
    }

    /// Failures sort the same way as for any other query, so a 429 can start the same wait as sending ideas.
    @Test func aRateLimitedAccountQueryIsRateLimited() async {
        let client = GraphQLBufferClient(transport: CannedTransport(.tooManyRequests(retryAfter: 60)))

        await #expect(throws: BufferError.rateLimited(retryAfter: 60)) {
            try await client.account(accessToken: "token")
        }
    }

    /// The cache is JSON, so an account has to survive the round trip whole.
    @Test func anAccountRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(BufferAccount.mock)

        #expect(try JSONDecoder().decode(BufferAccount.self, from: data) == .mock)
    }

    // MARK: - The profile picture

    /// Only Buffer's own bucket, exactly, over `https`.
    @Test func aPictureOnBuffersBucketIsAllowed() {
        let url = BufferAccount.avatarURL(from: "https://buffer-account-avatars-bucket.s3.amazonaws.com/example/a.png")

        #expect(url?.host() == BufferAccount.avatarHost)
    }

    @Test(arguments: [
        "http://buffer-account-avatars-bucket.s3.amazonaws.com/example/a.png",
        "https://buffer-account-avatars-bucket.s3.amazonaws.com.evil.example/example/a.png",
        "https://evil.example/buffer-account-avatars-bucket.s3.amazonaws.com/a.png",
        "https://another-bucket.s3.amazonaws.com/example/a.png",
        "https://s3.amazonaws.com/buffer-account-avatars-bucket/example/a.png",
        "https://xbuffer-account-avatars-bucket.s3.amazonaws.com/example/a.png",
        "https://BUFFER-ACCOUNT-AVATARS-BUCKET.s3.amazonaws.com/example/a.png",
        "https://buffer-account-avatars-bucket.s3.amazonaws.com:8443/example/a.png",
        "https://buffer-account-avatars-bucket.s3.amazonaws.com@evil.example/a.png",
        "https://user@buffer-account-avatars-bucket.s3.amazonaws.com/example/a.png",
        "https://buffer-account-avatars-bucket%2Es3.amazonaws.com/example/a.png",
        "ftp://buffer-account-avatars-bucket.s3.amazonaws.com/example/a.png",
        "/example/a.png",
        "",
    ])
    func anyOtherPictureIsNot(avatar: String) {
        #expect(BufferAccount.avatarURL(from: avatar) == nil)
    }

    /// The chip shows initials instead, and nothing is requested.
    @Test func aPictureBufferServesFromElsewhereIsDropped() async throws {
        let body = #"{"data":{"account":{"name":"Ada","email":null,"avatar":"https://evil.example/a.png"}}}"#
        let client = GraphQLBufferClient(transport: CannedTransport(.init(body: body)))

        let account = try await client.account(accessToken: "token")

        #expect(account.avatarURL == nil)
        #expect(account.displayName == "Ada")
    }

    /// Every account goes through the same check, including one read back from the Keychain.
    @Test func aSavedPictureFromElsewhereIsDropped() throws {
        let json = #"{"name":"Ada","email":"ada@example.com","avatarURL":"https:\/\/evil.example\/a.png"}"#

        let account = try JSONDecoder().decode(BufferAccount.self, from: Data(json.utf8))

        #expect(account.avatarURL == nil)
        let elsewhere = URL(string: "https://evil.example/a.png")
        #expect(BufferAccount(name: "Ada", email: nil, avatarURL: elsewhere).avatarURL == nil)
    }

    /// What 1.1 saved has no picture, and says it wasn't asked for, so the next foreground asks.
    @Test func anAccountSavedBy1Point1StillLoads() throws {
        let json = #"{"account":{"name":"Ada Lovelace","email":"ada@example.com"},"fetchedAt":1000}"#

        let saved = try JSONDecoder().decode(SavedAccount.self, from: Data(json.utf8))

        #expect(saved.account == BufferAccount(name: "Ada Lovelace", email: "ada@example.com"))
        #expect(!saved.askedForAvatar)
        #expect(SavedAccount(account: .mock, fetchedAt: saved.fetchedAt).askedForAvatar)
    }

    @Test func aSavedAccountRoundTripsWithItsPicture() throws {
        let saved = SavedAccount(account: .mock, fetchedAt: Date(timeIntervalSinceReferenceDate: 1_000))

        let decoded = try JSONDecoder().decode(SavedAccount.self, from: JSONEncoder().encode(saved))

        #expect(decoded == saved)
        #expect(decoded.account.avatarURL != nil)
    }
}
