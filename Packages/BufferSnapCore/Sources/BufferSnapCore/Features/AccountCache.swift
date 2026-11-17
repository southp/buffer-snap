import Foundation
import OSLog
import Observation

/// Who's signed in, for `AppModel`: the account as saved at the last fetch, and when to ask Buffer again.
///
/// It asks right after a sign-in, then at most once an hour, as the query counts toward the same rate limit as sending
/// ideas. A failure keeps what's saved, and never signs anyone out: losing the session is `AppModel.checkSession()`'s
/// to find out. Why its own Keychain item: `docs/decisions/92-account-cache.md`.
@Observable
@MainActor
final class AccountCache {
    /// How long a fetched account is good for before the next foreground asks again.
    static let refreshInterval: TimeInterval = 60 * 60

    private(set) var account: BufferAccount?

    @ObservationIgnored private let source: any AccountSource
    @ObservationIgnored private let store: any AccountStore
    @ObservationIgnored private let now: @Sendable () -> Date
    /// When Buffer last answered the account query, with the account or a refusal.
    @ObservationIgnored private var askedAt: Date?
    /// Changes with each sign-in and sign-out, so a fetch that finishes after one can't show the account it was for.
    @ObservationIgnored private var generation = 0
    /// The generation a fetch in flight is for, so the same session doesn't ask twice at once.
    @ObservationIgnored private var fetchingGeneration: Int?

    init(source: any AccountSource, store: any AccountStore, now: @escaping @Sendable () -> Date) {
        self.source = source
        self.store = store
        self.now = now
    }

    /// Shows the account saved by an earlier launch, for a session found in the Keychain.
    func restore() {
        let saved = store.load()
        account = saved?.account
        askedAt = saved?.fetchedAt
    }

    /// Forgets the account, here and in the Keychain: someone signed out, Buffer ended the session, or another account
    /// may have just signed in.
    func forget() {
        generation += 1
        account = nil
        askedAt = nil
        do {
            try store.clear()
        } catch {
            // The next sign-in clears it again, and until then nobody is signed in to show it.
            let errorType = String(describing: type(of: error))
            Logger.auth.error("Can't remove the saved account: \(errorType, privacy: .public)")
        }
    }

    /// Asks Buffer, unless it answered within the hour.
    func refreshIfDue() async {
        if let askedAt, (0..<Self.refreshInterval).contains(now().timeIntervalSince(askedAt)) {
            return
        }
        await refresh()
    }

    /// Asks Buffer who the account is, and saves the answer.
    func refresh() async {
        let generation = generation
        guard fetchingGeneration != generation else {
            return
        }
        fetchingGeneration = generation
        defer {
            if fetchingGeneration == generation {
                fetchingGeneration = nil
            }
        }
        do {
            let fetched = try await source.fetchAccount()
            guard generation == self.generation else {
                return
            }
            let saved = SavedAccount(account: fetched, fetchedAt: now())
            account = fetched
            askedAt = saved.fetchedAt
            try store.save(saved)
        } catch {
            if generation == self.generation, Self.reachedBuffer(error) {
                askedAt = now()
            }
            // Whatever was showing stays: the name is only a label.
            Logger.auth.notice("Can't refresh the account: \(String(describing: error), privacy: .public)")
        }
    }

    /// Whether the request got to Buffer, so it counts toward the hour. Offline, or waiting out a rate limit, it
    /// didn't, so the next foreground may try again.
    private static func reachedBuffer(_ error: any Error) -> Bool {
        switch error {
        case BufferError.connection, BufferError.rateLimited, AuthError.network:
            false
        default:
            true
        }
    }
}
