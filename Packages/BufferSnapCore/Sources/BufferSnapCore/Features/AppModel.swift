import Observation

/// App-wide state: which top-level screen to show.
@Observable
@MainActor
public final class AppModel {
    /// The top-level screen.
    public enum Route: Sendable, Equatable {
        case signedOut
        /// The capture screen, the first one after sign-in.
        case capture
        /// The capture list, one step on from the capture screen.
        case captureList
    }

    /// What the sign-in screen tells the user about the last attempt, or about why they're back on it.
    public enum SignInNotice: Sendable, Equatable {
        /// They closed Buffer's page.
        case cancelled
        /// They declined on Buffer's page.
        case denied
        /// Buffer couldn't be reached.
        case unreachable
        /// Anything else that stopped sign-in.
        case failed
        /// They were signed in, and Buffer stopped accepting the session.
        case sessionEnded
        /// They signed out, but the saved tokens couldn't be removed.
        case signOutFailed
    }

    public private(set) var route: Route
    public private(set) var signInNotice: SignInNotice?
    public private(set) var isSigningIn = false

    private let auth: any AuthService

    /// Starts on the right screen for a saved session, without waiting for anything. So the first frame is already
    /// right, and `showCapture()` works from the moment the app exists, as a cold launch from the widget needs.
    public init(auth: any AuthService) {
        self.auth = auth
        route = auth.hasSavedSession() ? .capture : .signedOut
    }

    /// Signs in and, on success, moves to the capture screen. Otherwise stays here and says why.
    public func signIn() async {
        guard route == .signedOut, !isSigningIn else {
            return
        }
        isSigningIn = true
        signInNotice = nil
        defer {
            isSigningIn = false
        }
        do {
            try await auth.signIn()
            route = .capture
        } catch {
            signInNotice = Self.notice(for: error)
        }
    }

    /// Signs out and moves to the sign-in screen.
    public func signOut() async {
        do {
            try await auth.signOut()
            signInNotice = nil
        } catch {
            signInNotice = .signOutFailed
        }
        route = .signedOut
    }

    /// Checks that the session still works, refreshing the token if it's due, for when the app comes to the foreground.
    /// Only losing the session changes anything: failing to reach Buffer is no reason to interrupt someone offline.
    public func checkSession() async {
        guard route != .signedOut else {
            return
        }
        do {
            _ = try await auth.validAccessToken()
        } catch let error as AuthError where error.requiresSignIn {
            // They may have signed out during the check. That's not a session that ended on them.
            if route != .signedOut {
                route = .signedOut
                signInNotice = .sessionEnded
            }
        } catch {
            // Offline, or Buffer is having a bad moment. The next check, or the next upload, tries again.
        }
    }

    /// Moves to the capture screen, unless signed out.
    public func showCapture() {
        if route != .signedOut {
            route = .capture
        }
    }

    /// Moves to the capture list, unless signed out.
    public func showCaptureList() {
        if route != .signedOut {
            route = .captureList
        }
    }

    private static func notice(for error: any Error) -> SignInNotice {
        switch error as? AuthError {
        case .cancelled:
            .cancelled
        case .denied:
            .denied
        case .network:
            .unreachable
        default:
            .failed
        }
    }
}
