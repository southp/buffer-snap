import AuthenticationServices
import BufferSnapCore
import OSLog
import UIKit

/// Shows Buffer's sign-in page in `ASWebAuthenticationSession`, and returns the URL it comes back through.
///
/// The callback scheme needs no `CFBundleURLTypes` entry: the session itself watches for it, and the page it opens
/// forwards to it (`site/oauth/`).
///
/// The page doesn't share Safari's cookies, so it never starts out signed in to a Buffer account from before. Buffer
/// leaves out the refresh token when someone switches account from there
/// (`docs/decisions/85-private-sign-in-sheet.md`).
@MainActor
final class SystemWebAuthenticator: NSObject, WebAuthenticator, ASWebAuthenticationPresentationContextProviding {
    /// The session in progress, which nothing else keeps alive while the page is open.
    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL, any Error>?

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        guard continuation == nil else {
            throw AuthError.authorizationFailed
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = Self.makeSession(url: url, callbackScheme: callbackScheme) { callbackURL, error in
                let result = Self.result(callbackURL: callbackURL, error: error)
                Task { @MainActor in
                    self.finish(with: result)
                }
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                finish(with: .failure(AuthError.authorizationFailed))
            }
        }
    }

    /// A session with its own, empty cookie store, which it throws away when it ends.
    static func makeSession(
        url: URL,
        callbackScheme: String,
        completionHandler: @escaping ASWebAuthenticationSession.CompletionHandler
    ) -> ASWebAuthenticationSession {
        let session = ASWebAuthenticationSession(
            url: url,
            callback: .customScheme(callbackScheme),
            completionHandler: completionHandler
        )
        session.prefersEphemeralWebBrowserSession = true
        return session
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        return window ?? ASPresentationAnchor()
    }

    /// Reports a result once, whichever of a failed start and the session's own callback comes first.
    private func finish(with result: Result<URL, any Error>) {
        session = nil
        continuation?.resume(with: result)
        continuation = nil
    }

    private nonisolated static func result(callbackURL: URL?, error: (any Error)?) -> Result<URL, any Error> {
        if let callbackURL {
            return .success(callbackURL)
        }
        if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
            return .failure(AuthError.cancelled)
        }
        Logger.signIn.error("The web sign-in session failed: \(String(describing: error), privacy: .public)")
        return .failure(AuthError.authorizationFailed)
    }
}

extension Logger {
    fileprivate static let signIn = Logger(subsystem: "me.southp.buffersnap", category: "auth")
}
