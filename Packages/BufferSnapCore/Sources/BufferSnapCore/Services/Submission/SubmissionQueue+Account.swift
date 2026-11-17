/// Where `AppModel` gets the signed-in account from. `SubmissionQueue` does it; a protocol so `AppModel`'s tests can
/// stand it in.
public protocol AccountSource: Sendable {
    /// Asks Buffer who the account is. Throws a `BufferError` or an `AuthError`, and `BufferError.rateLimited` without
    /// asking while Buffer has asked to wait.
    func fetchAccount() async throws -> BufferAccount
}

// The account query counts toward the same rate limit as sending ideas, so it goes through the queue, which keeps that
// limit: it never asks while the queue waits one out, and a 429 starts the same wait.
extension SubmissionQueue: AccountSource {
    public func fetchAccount() async throws -> BufferAccount {
        guard rateLimitedUntil == nil else {
            throw BufferError.rateLimited(retryAfter: nil)
        }
        let token = try await auth.validAccessToken()
        do {
            return try await client.account(accessToken: token)
        } catch BufferError.unauthorized {
            // The next token is refreshed first. Whether the session is over is `checkSession()`'s to find out.
            await auth.accessTokenRejected(token)
            throw BufferError.unauthorized
        } catch BufferError.rateLimited(let retryAfter) {
            // Checked again: the limit may have started while this was waiting for Buffer.
            if rateLimitedUntil == nil {
                startRateLimit(retryAfter: retryAfter)
            }
            throw BufferError.rateLimited(retryAfter: retryAfter)
        }
    }
}

/// No account to show, for tests and previews that don't care about it.
public struct NoAccountSource: AccountSource {
    public init() {}

    public func fetchAccount() async throws -> BufferAccount {
        throw BufferError.connection
    }
}
