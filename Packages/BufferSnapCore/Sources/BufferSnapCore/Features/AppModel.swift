import OSLog
import Observation

/// App-wide state: whether anyone is signed in to Buffer, and what the app has to ask or say about it.
@Observable
@MainActor
public final class AppModel {
    /// What the list's sign-in row shows while nobody is signed in.
    public struct SignInPrompt: Sendable, Equatable {
        public let notice: SignInNotice?
        public let isSigningIn: Bool

        public init(notice: SignInNotice?, isSigningIn: Bool) {
            self.notice = notice
            self.isSigningIn = isSigningIn
        }
    }

    /// What the list's sign-in row tells the user about the last attempt, or about why it's back.
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

    /// Whether there's a Buffer session to send with. Nothing else depends on this: capturing and the list work either
    /// way, and the queue waits quietly without a session.
    public private(set) var isSignedIn: Bool
    public private(set) var signInNotice: SignInNotice?
    public private(set) var isSigningIn = false
    /// A press couldn't listen because there was no Live Activity to show it on, so the app has to say why.
    public private(set) var isShowingLiveActivitiesNotice = false
    /// How many ideas a sign-in that just finished asks about ("Send N ideas to this account?"), until answered.
    /// `nil` means there's no question: `docs/decisions/68-ideas-at-sign-in.md`.
    public private(set) var ideasToConfirm: Int?

    private let auth: any AuthService
    private let ideas: any IdeasAtSignIn

    /// Reads the saved session without waiting for anything, so the first frame already shows the right state.
    ///
    /// `ideas` holds what's waiting before each sign-in. If that throws, the sign-in doesn't happen.
    public init(auth: any AuthService, ideas: any IdeasAtSignIn = NoIdeasAtSignIn()) {
        self.auth = auth
        self.ideas = ideas
        isSignedIn = auth.hasSavedSession()
    }

    /// What the list's sign-in row shows, or `nil` while someone is signed in.
    public var signInPrompt: SignInPrompt? {
        isSignedIn ? nil : SignInPrompt(notice: signInNotice, isSigningIn: isSigningIn)
    }

    /// Signs in, and asks about whatever was waiting. If it doesn't work out, says why in the list's row.
    public func signIn() async {
        guard !isSignedIn, !isSigningIn else {
            return
        }
        isSigningIn = true
        signInNotice = nil
        defer {
            isSigningIn = false
        }
        do {
            try await ideas.holdPendingCaptures()
            try await auth.signIn()
        } catch {
            signInNotice = Self.notice(for: error)
            await releaseHeldCaptures()
            return
        }
        isSignedIn = true
        await askAboutHeldIdeas()
    }

    /// The person chose to send what was waiting to the account they just signed in to.
    public func sendHeldIdeas() async {
        ideasToConfirm = nil
        do {
            try await ideas.sendHeldIdeas()
        } catch {
            // What's held stays held, with Resend, so nothing is lost by not reaching the store.
            Logger.auth.error("Can't send what was held at sign-in: \(Self.describe(error), privacy: .public)")
        }
    }

    /// The person chose not to send what was waiting. It stays held, with Resend on each batch, so nothing is lost and
    /// nothing is asked again until the next sign-in.
    public func keepHeldIdeas() {
        ideasToConfirm = nil
    }

    /// Signs out. The list stays, with every idea on it.
    public func signOut() async {
        do {
            try await auth.signOut()
            signInNotice = nil
            await releaseHeldCaptures()
        } catch {
            signInNotice = .signOutFailed
        }
        isSignedIn = false
        ideasToConfirm = nil
    }

    /// Checks that the session still works, refreshing the token if it's due, for when the app comes to the foreground.
    /// Only losing the session changes anything: failing to reach Buffer is no reason to interrupt someone offline.
    public func checkSession() async {
        guard isSignedIn else {
            // A sign-in that never finished, such as a crash during it, may have left captures held.
            if !isSigningIn {
                await releaseHeldCaptures()
            }
            return
        }
        do {
            _ = try await auth.validAccessToken()
        } catch let error as AuthError where error.requiresSignIn {
            // They may have signed out during the check. That's not a session that ended on them.
            if isSignedIn {
                isSignedIn = false
                signInNotice = .sessionEnded
                ideasToConfirm = nil
                await releaseHeldCaptures()
            }
        } catch {
            // Offline, or Buffer is having a bad moment. The next check, or the next upload, tries again.
        }
    }

    /// Says that dictating needs Live Activities.
    public func showLiveActivitiesNotice() {
        isShowingLiveActivitiesNotice = true
    }

    public func dismissLiveActivitiesNotice() {
        isShowingLiveActivitiesNotice = false
    }

    /// Asks about what's held, once, after a sign-in. Whatever is held at this moment goes into the count, including
    /// anything saved while Buffer's page was open.
    private func askAboutHeldIdeas() async {
        do {
            try await ideas.holdPendingCaptures()
            let count = try await ideas.heldIdeaCount()
            ideasToConfirm = count > 0 ? count : nil
        } catch {
            // What's held stays held, with Resend, so nothing is lost by not asking.
            Logger.auth.error("Can't ask about what's held at sign-in: \(Self.describe(error), privacy: .public)")
        }
    }

    /// Nobody ended up signed in, so what's held can go back to waiting. Failing to write that loses nothing: it's
    /// held again at the next sign-in, and shows as waiting meanwhile.
    private func releaseHeldCaptures() async {
        do {
            try await ideas.releaseHeldCaptures()
        } catch {
            Logger.auth.error("Can't release what's held: \(Self.describe(error), privacy: .public)")
        }
    }

    /// A store's error can name a file, so only its type goes in the log.
    private static func describe(_ error: any Error) -> String {
        String(describing: type(of: error))
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
