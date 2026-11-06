import BufferSnapCore
import Foundation
import Testing

struct AppLinkTests {
    @Test func captureURLOpensTheCaptureScreen() throws {
        let url = try #require(AppLink.capture.url)

        #expect(url.absoluteString == "buffersnap://capture")
        #expect(AppLink(url: url) == .capture)
    }

    @Test(arguments: ["BufferSnap://Capture", "buffersnap://capture/", "buffersnap://capture?from=widget"])
    func captureIgnoresCaseAndExtras(string: String) throws {
        #expect(AppLink(url: try #require(URL(string: string))) == .capture)
    }

    /// Sign-in's return: `ASWebAuthenticationSession` handles it, and the app must not act on it.
    @Test(arguments: [
        "buffersnap://oauth?code=abc&state=xyz",
        "buffersnap://oauth",
        "buffersnap://",
        "buffersnap://list",
        "https://capture",
        "https://southp.github.io/buffer-snap/oauth/?code=abc",
    ])
    func everythingElseIsNotALink(string: String) throws {
        #expect(AppLink(url: try #require(URL(string: string))) == nil)
    }
}
