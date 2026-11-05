/// Buffer's API, as far as this app needs it. Each call takes the token, so whoever calls decides what to do when
/// Buffer rejects one.
public protocol BufferClient: Sendable {
    /// The first organization the account belongs to (`docs/decisions/44-first-organization.md`). Throws a
    /// `BufferError`.
    func firstOrganizationID(accessToken: String) async throws -> String

    /// Creates one idea. Throws a `BufferError`. `.connection` and `.serverTrouble` don't mean that no idea was
    /// created: `docs/decisions/44-duplicate-ideas.md`.
    func createIdea(text: String, organizationID: String, accessToken: String) async throws
}

/// How a Buffer API call failed, sorted by what to do about it. Never holds a token, capture text or Buffer's own
/// messages, which can repeat what was sent, so all of this is safe to log.
public enum BufferError: Error, Equatable, Sendable {
    /// No answer came back: offline, timed out, or the connection dropped. The request may still have arrived.
    case connection
    /// Buffer didn't accept the access token. It did nothing with the request.
    case unauthorized
    /// Too many requests. `retryAfter` is how many seconds Buffer asked for, if it did.
    case rateLimited(retryAfter: Double?)
    /// Buffer answered with an error that may pass, such as a 500. It may have acted on the request first.
    case serverTrouble
    /// Buffer refused, and asking again won't change that. `reason` is an error type or code, never its message.
    case rejected(reason: String)
}

/// A `BufferClient` that never touches the network, for tests and the mocked app. Each call to `createIdea` throws the
/// next of `failures`, and once they run out it succeeds.
public actor MockBufferClient: BufferClient {
    public private(set) var createdIdeas: [String] = []
    private var failures: [BufferError]

    public init(failures: [BufferError] = []) {
        self.failures = failures
    }

    public func firstOrganizationID(accessToken: String) -> String {
        "mock-organization"
    }

    public func createIdea(text: String, organizationID: String, accessToken: String) throws {
        if !failures.isEmpty {
            throw failures.removeFirst()
        }
        createdIdeas.append(text)
    }
}
