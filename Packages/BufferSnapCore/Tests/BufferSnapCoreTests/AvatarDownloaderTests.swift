import BufferSnapCore
import Foundation
import Testing

/// Downloading the picture: only from Buffer's bucket, with nothing but the request, and only an image comes back.
struct AvatarDownloaderTests {
    @Test func aPictureOnBuffersBucketDownloads() async throws {
        let transport = CannedImageTransport()
        let url = AvatarFixtures.url("ada")

        let image = try await HTTPAvatarDownloader(transport: transport).image(at: url)

        #expect(image == AvatarFixtures.png)
        let request = try #require(await transport.requests.first)
        #expect(request.url == url)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(!request.httpShouldHandleCookies)
    }

    /// Whoever calls it, nothing but the bucket is ever requested.
    @Test(arguments: [
        "https://evil.example/a.png",
        "https://buffer-account-avatars-bucket.s3.amazonaws.com.evil.example/a.png",
        "http://buffer-account-avatars-bucket.s3.amazonaws.com/a.png",
    ])
    func anyOtherURLIsNeverRequested(url: String) async throws {
        let transport = CannedImageTransport()
        let downloader = HTTPAvatarDownloader(transport: transport)

        await #expect(throws: AvatarError.notAllowed) {
            try await downloader.image(at: try #require(URL(string: url)))
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test(arguments: [301, 403, 404, 500])
    func anythingButA200IsNoPicture(status: Int) async {
        let downloader = HTTPAvatarDownloader(transport: CannedImageTransport(status: status))

        await #expect(throws: AvatarError.status(status)) {
            try await downloader.image(at: AvatarFixtures.url("ada"))
        }
    }

    /// A page of HTML, or a picture cut off halfway, isn't saved.
    @Test(arguments: [Data("<html>Not here</html>".utf8), AvatarFixtures.png.prefix(20), Data()])
    func whatIsntAnImageIsNoPicture(body: Data) async {
        let downloader = HTTPAvatarDownloader(transport: CannedImageTransport(body: body))

        await #expect(throws: AvatarError.notAnImage) {
            try await downloader.image(at: AvatarFixtures.url("ada"))
        }
    }

    /// `URLError`'s description names the URL, which holds the account's ID, so only its code is kept.
    @Test func aConnectionFailureKeepsOnlyItsCode() async {
        let transport = CannedImageTransport(failure: URLError(.notConnectedToInternet))
        let downloader = HTTPAvatarDownloader(transport: transport)

        await #expect(throws: AvatarError.connection(code: URLError.notConnectedToInternet.rawValue)) {
            try await downloader.image(at: AvatarFixtures.url("ada"))
        }
    }

    /// A redirect could lead anywhere, so the session doesn't follow it.
    @Test func theSessionDoesntFollowRedirects() async throws {
        let session = URLSession.forAvatars()
        let delegate = try #require(session.delegate as? RefusesRedirects)
        let task = session.dataTask(with: AvatarFixtures.url("ada"))
        let redirect = try #require(
            HTTPURLResponse(url: AvatarFixtures.url("ada"), statusCode: 302, httpVersion: nil, headerFields: nil)
        )

        let next = await delegate.urlSession(
            session, task: task, willPerformHTTPRedirection: redirect,
            newRequest: URLRequest(url: try #require(URL(string: "https://evil.example/a.png")))
        )

        #expect(next == nil)
        #expect(session.configuration.urlCache == nil)
        #expect(session.configuration.httpCookieStorage == nil)
        session.invalidateAndCancel()
    }

    @Test func theMockedAppGetsItsMadeUpPictureOffline() async throws {
        let downloader = MockAvatarDownloader(picture: AvatarFixtures.png)

        #expect(try await downloader.image(at: AvatarFixtures.url("ada")) == AvatarFixtures.png)
        await #expect(throws: AvatarError.notAllowed) {
            try await downloader.image(at: try #require(URL(string: "https://evil.example/a.png")))
        }
    }
}
