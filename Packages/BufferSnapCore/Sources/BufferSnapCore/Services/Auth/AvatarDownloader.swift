import Foundation
import ImageIO
import OSLog

/// Why a profile picture didn't download. Never holds the URL, so it's safe to log whole.
public enum AvatarError: Error, Equatable, Sendable {
    /// The URL isn't on Buffer's bucket (`BufferAccount.avatarHost`), so it wasn't requested.
    case notAllowed
    /// The request didn't get an answer, with `URLError`'s code.
    case connection(code: Int)
    /// The bucket answered with something other than 200, including a redirect, which isn't followed.
    case status(Int)
    /// What came back isn't an image the app can draw, or is too big to be a profile picture, in bytes or in pixels.
    case notAnImage
}

/// Downloads the signed-in account's profile picture. A protocol so tests and the mocked app never touch the network.
public protocol AvatarDownloader: Sendable {
    /// The picture at `url`, as image bytes. Throws an `AvatarError`.
    func image(at url: URL) async throws -> Data
}

/// Downloads the picture from Buffer's bucket on S3. Not Buffer's API, so it doesn't count toward Buffer's rate limit,
/// and it sends no token: the request alone, through `URLSession.forAvatars()`.
public struct HTTPAvatarDownloader: AvatarDownloader {
    /// Far bigger than any profile picture, and small enough that a wrong answer can't fill the iPhone.
    static let maxBytes = 5 * 1024 * 1024
    /// Far wider and taller than a chip needs, and small enough that drawing it can't take much memory.
    static let maxPixels = 4096

    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport) {
        self.transport = transport
    }

    public func image(at url: URL) async throws -> Data {
        // Checked again here, so nothing but Buffer's bucket is ever requested, whatever the caller passed.
        guard BufferAccount.isAllowedAvatarURL(url) else {
            throw AvatarError.notAllowed
        }
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = false
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as URLError {
            // Its description names the URL, so only the code goes on.
            throw AvatarError.connection(code: error.code.rawValue)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw AvatarError.status(status)
        }
        guard data.count <= Self.maxBytes, Self.isImage(data) else {
            throw AvatarError.notAnImage
        }
        return data
    }

    /// Whether ImageIO can draw `data`: a page of HTML or a cut-off file can't. Its size is read from its header first,
    /// so a huge one is turned down without being decoded.
    static func isImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            (1...maxPixels).contains(width), (1...maxPixels).contains(height)
        else {
            return false
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
    }
}

/// No picture to show, for tests and previews that don't care about it.
public struct NoAvatarDownloader: AvatarDownloader {
    public init() {}

    public func image(at url: URL) async throws -> Data {
        throw AvatarError.connection(code: URLError.notConnectedToInternet.rawValue)
    }
}

/// The same made-up picture for any allowed URL, for the mocked app: nothing goes over the network.
public struct MockAvatarDownloader: AvatarDownloader {
    private let picture: Data

    public init(picture: Data) {
        self.picture = picture
    }

    public func image(at url: URL) async throws -> Data {
        guard BufferAccount.isAllowedAvatarURL(url) else {
            throw AvatarError.notAllowed
        }
        return picture
    }
}

extension URLSession {
    /// For the profile picture: no cookies, no cache (the picture is kept by `FileAvatarImageStore`, which sign-out
    /// clears), and no redirects, so the request can't end up anywhere but Buffer's bucket.
    public static func forAvatars() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration, delegate: RefusesRedirects(), delegateQueue: nil)
    }
}

/// Answers every redirect with no request, so the redirect itself comes back, and `HTTPAvatarDownloader` turns it
/// down as a status other than 200.
public final class RefusesRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
