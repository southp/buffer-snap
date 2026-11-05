import Foundation

/// Everything that identifies this app to Buffer's OAuth server. To change the app client, change it here.
public enum BufferOAuth {
    /// A public client: it has no secret, and PKCE authenticates it, so this ID is fine to commit.
    public static let clientID = "U9uUzfVMfWkpU5P9PiVXL3W1o52xCFevd0B76yas3Br"

    /// Registered with Buffer, which compares it character for character. Buffer only redirects to HTTPS, so this page
    /// forwards its query string to `callbackScheme` (`docs/decisions/43-oauth-redirect-page.md`).
    public static let redirectURI = "https://southp.github.io/buffer-snap/oauth/"

    /// The scheme the redirect page forwards to, which the web sign-in session watches for.
    public static let callbackScheme = "buffersnap"

    /// `offline_access` is what makes Buffer return a refresh token.
    public static let scopes = "ideas:write account:read offline_access"

    static let tokenEndpoint = url("https://auth.buffer.com/token")

    /// The page that asks the user to approve this app. `prompt=consent` isn't in the parameter table of Buffer's guide
    /// but is in its example request and its sample app.
    static func authorizationURL(state: String, codeChallenge: String) -> URL? {
        var components = URLComponents(string: "https://auth.buffer.com/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        return components?.url
    }

    private static func url(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Not a URL: \(string)")
        }
        return url
    }
}
