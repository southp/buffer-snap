import BufferSnapCore
import Foundation
import Synchronization
import Testing

/// What an `OAuthAuthService` test needs: a server, a store and a clock that are shared by every service it makes, so a
/// second service stands for the same app after a relaunch.
struct OAuthFixture {
    let server = FakeBufferServer()
    let store = FlakySessionStore()
    let clock = TestClock()

    func makeService(web: FakeWebAuthenticator = .approving()) -> OAuthAuthService {
        let clock = clock
        return OAuthAuthService(web: web, transport: server, store: store, now: { clock.now })
    }

    /// A service restored from a session saved earlier, whose access token has `lifetime` seconds left.
    func makeRestoredService(lifetime: TimeInterval = -1) async throws -> OAuthAuthService {
        try store.save(await server.grantSession(expiresAt: clock.now.addingTimeInterval(lifetime)))
        return makeService()
    }

    func refreshRequests() async -> [[String: String]] {
        await server.requests.filter { $0["grant_type"] == "refresh_token" }
    }
}

/// The clock an `OAuthAuthService` reads in a test, which only moves when told to.
final class TestClock: Sendable {
    private let date = Mutex(Date(timeIntervalSinceReferenceDate: 1_000_000))

    var now: Date {
        date.withLock { $0 }
    }

    func advance(by seconds: TimeInterval) {
        date.withLock { $0 = $0.addingTimeInterval(seconds) }
    }
}

/// A `SessionStore` whose reads and writes can be made to fail, like a Keychain that isn't available.
final class FlakySessionStore: SessionStore {
    private let base: InMemorySessionStore
    private let failures = Mutex((loads: false, saves: false, clears: false))

    init(session: AuthSession? = nil) {
        base = InMemorySessionStore(session: session)
    }

    func fail(loads: Bool = false, saves: Bool = false, clears: Bool = false) {
        failures.withLock { $0 = (loads, saves, clears) }
    }

    func load() throws -> AuthSession? {
        if failures.withLock({ $0.loads }) {
            throw TestError()
        }
        return base.load()
    }

    func save(_ session: AuthSession) throws {
        if failures.withLock({ $0.saves }) {
            throw TestError()
        }
        base.save(session)
    }

    func clear() throws {
        if failures.withLock({ $0.clears }) {
            throw TestError()
        }
        base.clear()
    }
}

/// Stands in for `ASWebAuthenticationSession`: gives the URL it was opened with to `respond`, as if the user had
/// finished on Buffer's page and the redirect page had forwarded the result.
final class FakeWebAuthenticator: WebAuthenticator {
    private let respond: @Sendable (URL) throws -> URL
    private let opened = Mutex<[(url: URL, scheme: String)]>([])

    init(respond: @escaping @Sendable (URL) throws -> URL) {
        self.respond = respond
    }

    /// Comes back with `code` and the `state` it was given, as Buffer does when the user approves.
    static func approving(code: String = FakeBufferServer.validCode) -> FakeWebAuthenticator {
        FakeWebAuthenticator { url in
            try callback("code=\(code)&state=\(try #require(url.queryValue("state")))")
        }
    }

    static func callback(_ query: String) throws -> URL {
        try #require(URL(string: "buffersnap://oauth?\(query)"))
    }

    var openedURLs: [URL] {
        opened.withLock { $0.map(\.url) }
    }

    var openedSchemes: [String] {
        opened.withLock { $0.map(\.scheme) }
    }

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        opened.withLock { $0.append((url, callbackScheme)) }
        return try respond(url)
    }
}

extension URL {
    func queryValue(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
}

/// Buffer's token endpoint, including the rule that matters: a refresh token works once, and using one again revokes
/// the grant. A test that reuses one sees the rejection the real server would give. The rejection's status and body
/// are what the real endpoint returned when probed with a bad token.
actor FakeBufferServer: HTTPTransport {
    enum Fault: Sendable {
        /// The request never arrives.
        case unreachable
        /// The server does the work, but the response never comes back, like a crash or a dropped connection.
        case responseLost
        /// The server answers this instead of doing the work.
        case response(status: Int, body: String)
    }

    static let validCode = "valid-code"
    private static let endpoint = URL(fileURLWithPath: "/")

    /// Each request's form fields, decoded.
    private(set) var requests: [[String: String]] = []
    /// Each request's body as sent.
    private(set) var rawBodies: [String] = []
    private(set) var isGrantRevoked = false

    private var liveRefreshToken: String?
    private var tokensIssued = 0
    private var fault: Fault?
    private var omittedFields: Set<String> = []
    private var isHoldingNextResponse = false
    private var heldResponse: CheckedContinuation<Void, Never>?

    /// Starts as if the user had signed in earlier, and returns the session that left them with.
    func grantSession(expiresAt: Date) -> AuthSession {
        let tokens = issueTokens()
        return AuthSession(accessToken: tokens.access, refreshToken: tokens.refresh, expiresAt: expiresAt)
    }

    /// As if the user had revoked the app in Buffer's settings: every refresh token is dead from now on.
    func revokeGrant() {
        isGrantRevoked = true
    }

    /// Makes the next request fail as `fault` says.
    func failNextRequest(_ fault: Fault) {
        self.fault = fault
    }

    /// Leaves these fields out of each successful response.
    func omit(_ fields: Set<String>) {
        omittedFields = fields
    }

    /// Holds the next request until `releaseResponse()`, so a test can act while it's in flight.
    func holdNextResponse() {
        isHoldingNextResponse = true
    }

    func releaseResponse() {
        heldResponse?.resume()
        heldResponse = nil
    }

    /// Returns once the server holds a request. Lets other tasks run while it waits.
    func waitForHeldRequest() async {
        while heldResponse == nil {
            await Task.yield()
        }
    }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let body = String(bytes: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        rawBodies.append(body)
        let fields = Self.decodeForm(body)
        requests.append(fields)

        if isHoldingNextResponse {
            isHoldingNextResponse = false
            await withCheckedContinuation { heldResponse = $0 }
        }

        // Like URLSession: cancelling a request in flight fails it, whether or not the server has already acted on it.
        if Task.isCancelled {
            _ = respond(to: fields)
            throw URLError(.cancelled)
        }

        let fault = self.fault
        self.fault = nil
        switch fault {
        case .unreachable:
            throw URLError(.notConnectedToInternet)
        case .responseLost:
            _ = respond(to: fields)
            throw URLError(.networkConnectionLost)
        case .response(let status, let body):
            return Self.response(status: status, body: Data(body.utf8))
        case nil:
            return respond(to: fields)
        }
    }

    private func respond(to fields: [String: String]) -> (Data, URLResponse) {
        switch fields["grant_type"] {
        case "authorization_code" where fields["code"] == Self.validCode:
            return success()
        case "refresh_token" where !isGrantRevoked && fields["refresh_token"] == liveRefreshToken:
            return success()
        case "refresh_token":
            // Reuse detection: the grant is gone, new tokens included.
            isGrantRevoked = true
            return invalidGrant()
        default:
            return invalidGrant()
        }
    }

    private func success() -> (Data, URLResponse) {
        let tokens = issueTokens()
        var json: [String: Any] = [
            "access_token": tokens.access,
            "refresh_token": tokens.refresh,
            "token_type": "Bearer",
            "expires_in": 3600,
            "scope": BufferOAuth.scopes,
        ]
        for field in omittedFields {
            json[field] = nil
        }
        // A dictionary of JSON types can't fail to encode.
        let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        return Self.response(status: 200, body: data)
    }

    private func invalidGrant() -> (Data, URLResponse) {
        let body = #"{"error":"invalid_grant","error_description":"grant request is invalid"}"#
        return Self.response(status: 400, body: Data(body.utf8))
    }

    private func issueTokens() -> (access: String, refresh: String) {
        tokensIssued += 1
        let refresh = "refresh-\(tokensIssued)"
        liveRefreshToken = refresh
        return ("access-\(tokensIssued)", refresh)
    }

    private static func response(status: Int, body: Data) -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: endpoint, statusCode: status, httpVersion: nil, headerFields: nil)
        return (body, response ?? URLResponse())
    }

    private static func decodeForm(_ body: String) -> [String: String] {
        var fields: [String: String] = [:]
        for pair in body.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if let name = parts.first, let value = parts.last?.removingPercentEncoding {
                fields[name] = value
            }
        }
        return fields
    }
}
