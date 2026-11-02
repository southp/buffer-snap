import Observation

/// App-wide state: which top-level screen to show.
@Observable
@MainActor
public final class AppModel {
    /// The top-level screen.
    public enum Route: Sendable, Equatable {
        case signedOut
        case captures
    }

    public private(set) var route: Route = .signedOut

    private let auth: any AuthService

    public init(auth: any AuthService) {
        self.auth = auth
    }

    /// Signs in and, on success, moves to the capture list.
    public func signIn() async {
        do {
            try await auth.signIn()
            route = .captures
        } catch {
            // Stay signed out. Showing the error comes with real Buffer OAuth (MVP).
        }
    }
}
