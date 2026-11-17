import Foundation
import Synchronization

/// Keeps the signed-in account's profile picture between launches, so the chip shows it offline after a relaunch.
///
/// It only knows which URL the picture came from, so the app downloads it only when the URL changes. Not `async`, like
/// `AccountStore`: `AppModel` reads it before the first frame.
public protocol AvatarImageStore: Sendable {
    /// The saved picture's bytes, or `nil` if there's none or it can't be read.
    func load() -> Data?

    /// Whether the saved picture is the one at `url`.
    func holds(_ url: URL) -> Bool

    /// Replaces the saved picture with `image`, downloaded from `url`.
    func save(_ image: Data, from url: URL) throws

    /// Removes the saved picture, if there's one.
    func clear() throws
}

/// An `AvatarImageStore` that lasts as long as the process, for tests, previews and the mocked app.
public final class InMemoryAvatarImageStore: AvatarImageStore {
    private let saved: Mutex<(url: URL, image: Data)?>

    public init(image: Data? = nil, from url: URL? = nil) {
        if let image, let url {
            saved = Mutex((url, image))
        } else {
            saved = Mutex(nil)
        }
    }

    public func load() -> Data? {
        saved.withLock { $0?.image }
    }

    public func holds(_ url: URL) -> Bool {
        saved.withLock { $0?.url == url }
    }

    public func save(_ image: Data, from url: URL) {
        saved.withLock { $0 = (url, image) }
    }

    public func clear() {
        saved.withLock { $0 = nil }
    }
}
