import Foundation
import OSLog

/// Sends HTTP requests, so tests can stand in for Buffer's server.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPTransport {
    public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request)
    }

    /// For talking to Buffer's token endpoint: no cookies, and no cache that could hold a response with tokens in it.
    public static func forOAuth() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }
}

/// What Buffer's token endpoint returns. `refreshToken` can be missing if the client isn't allowed `offline_access`.
struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

/// Buffer's token endpoint: turns an authorization code or a refresh token into tokens.
struct TokenClient: Sendable {
    /// Buffer's `invalid_grant`: it won't accept this code or refresh token, and asking again won't change that.
    struct InvalidGrant: Error {}

    private struct ErrorBody: Decodable {
        let error: String
    }

    let transport: any HTTPTransport

    func exchange(code: String, verifier: String) async throws -> TokenResponse {
        try await post([
            ("client_id", BufferOAuth.clientID),
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", BufferOAuth.redirectURI),
            ("code_verifier", verifier),
        ])
    }

    func refresh(refreshToken: String) async throws -> TokenResponse {
        try await post([
            ("client_id", BufferOAuth.clientID),
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
        ])
    }

    /// Only `invalid_grant` means no: a 500, a 429, some other error or a body that makes no sense all throw
    /// `AuthError.server`, so they can't end a session that may well still be good.
    private func post(_ fields: [(String, String)]) async throws -> TokenResponse {
        var request = URLRequest(url: BufferOAuth.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data(Self.formEncoded(fields).utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            let code = (error as NSError).code
            Logger.auth.error("Can't reach the token endpoint: code \(code, privacy: .public)")
            throw AuthError.network
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let body = try? JSONDecoder().decode(ErrorBody.self, from: data) {
            // An OAuth error code from a short, fixed list, and never a secret.
            Logger.auth.error("Token endpoint error \(body.error, privacy: .public), HTTP \(status, privacy: .public)")
            if body.error == "invalid_grant" {
                throw InvalidGrant()
            }
            throw AuthError.server
        }
        guard (200..<300).contains(status), let tokens = try? JSONDecoder().decode(TokenResponse.self, from: data)
        else {
            // Never log the body: this might be a good response in a shape we didn't expect, with tokens in it.
            Logger.auth.error("Unexpected token endpoint response, HTTP \(status, privacy: .public)")
            throw AuthError.server
        }
        return tokens
    }

    /// Percent-encodes everything but RFC 3986's unreserved characters. `URLQueryItem` would leave a `+` alone, and a
    /// form body reads that as a space, which would corrupt a token that has one.
    private static func formEncoded(_ fields: [(String, String)]) -> String {
        let unreserved = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        return fields.map { name, value in
            "\(name)=\(value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "")"
        }
        .joined(separator: "&")
    }
}
