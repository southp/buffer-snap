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
        let body = #"{"data":{"account":{"name":"Ada Lovelace","email":"ada@example.com"}}}"#
        let transport = CannedTransport(.init(body: body))
        let client = GraphQLBufferClient(transport: transport)

        let account = try await client.account(accessToken: "token")

        #expect(account == BufferAccount(name: "Ada Lovelace", email: "ada@example.com"))
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        let sent = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        #expect(sent["query"] as? String == "query Account { account { name email } }")
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
}
