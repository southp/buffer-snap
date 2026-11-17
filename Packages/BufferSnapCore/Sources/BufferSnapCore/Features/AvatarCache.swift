import Foundation
import OSLog
import Observation

/// The signed-in account's profile picture, for `AccountCache`: the copy saved at the last download, and a download
/// whenever the account's picture URL changes.
///
/// Each URL is asked for at most once per launch, and a failed download, or one that isn't an image, keeps whatever
/// was showing. Nothing here touches the session: a picture is only a picture. The URL holds the account's ID, so it's
/// never logged (`docs/decisions/108-avatar-from-buffers-s3.md`).
@Observable
@MainActor
final class AvatarCache {
    /// The picture's bytes, or `nil` for initials.
    private(set) var image: Data?

    @ObservationIgnored private let downloader: any AvatarDownloader
    @ObservationIgnored private let store: any AvatarImageStore
    /// Changes with each `forget()`, so a download that finishes after one can't show the picture it was for.
    @ObservationIgnored private var generation = 0
    /// The URLs asked for since launch, or since the last `forget()`: never one twice, even if it failed.
    @ObservationIgnored private var requested: Set<URL> = []

    init(downloader: any AvatarDownloader, store: any AvatarImageStore) {
        self.downloader = downloader
        self.store = store
    }

    /// Shows the picture saved by an earlier launch, for a session found in the Keychain.
    func restore() {
        image = store.load()
    }

    /// Forgets the picture, here and on disk, whenever `AccountCache` forgets the account.
    func forget() {
        generation += 1
        image = nil
        requested = []
        removeSavedPicture()
    }

    /// Makes the picture the one at `url`: downloads it unless it's already saved or was already asked for, and
    /// removes the saved one if the account has no picture any more.
    func update(to url: URL?) async {
        guard let url else {
            image = nil
            removeSavedPicture()
            return
        }
        guard !store.holds(url), !requested.contains(url) else {
            return
        }
        requested.insert(url)
        let generation = generation
        let downloaded: Data
        do {
            downloaded = try await downloader.image(at: url)
        } catch {
            // Whatever was showing stays: the old picture, or initials.
            Logger.auth.notice("Can't download the account's picture: \(Self.describe(error), privacy: .public)")
            return
        }
        guard generation == self.generation else {
            return
        }
        image = downloaded
        do {
            try store.save(downloaded, from: url)
        } catch {
            // It still shows until the app quits, and the next launch downloads it again.
            Logger.auth.error("Can't save the account's picture: \(Self.describe(error), privacy: .public)")
        }
    }

    private func removeSavedPicture() {
        do {
            try store.clear()
        } catch {
            // The next sign-in clears it again, and until then nobody is signed in to show it.
            Logger.auth.error("Can't remove the saved picture: \(Self.describe(error), privacy: .public)")
        }
    }

    /// `AvatarError` never holds the URL, so it's logged whole. Anything else, only its type.
    private static func describe(_ error: any Error) -> String {
        if error is AvatarError {
            return String(describing: error)
        }
        return String(describing: type(of: error))
    }
}
