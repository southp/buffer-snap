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

    public private(set) var route: Route = .signedOut

    private let auth: any AuthService

    public init(auth: any AuthService) {
        self.auth = auth
    }

    /// Signs in and, on success, moves to the capture screen.
    public func signIn() async {
        do {
            try await auth.signIn()
            route = .capture
        } catch {
            // Stay signed out. Showing the error comes with real Buffer OAuth (MVP).
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
}
