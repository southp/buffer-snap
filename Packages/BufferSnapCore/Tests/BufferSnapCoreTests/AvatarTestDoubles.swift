import BufferSnapCore
import Foundation

/// Made-up pictures and URLs: never a real account's.
enum AvatarFixtures {
    /// A 1×1 PNG, the smallest picture ImageIO draws.
    static let png = Data(base64Encoded: pngBase64) ?? Data()
    private static let pngBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
    /// Another picture, told apart from `png` by its bytes.
    static let otherPNG = png + Data([0])

    /// A made-up picture URL on Buffer's bucket.
    static func url(_ name: String) -> URL {
        URL(string: "https://\(BufferAccount.avatarHost)/example/\(name).png") ?? URL(fileURLWithPath: "/")
    }
}

/// S3 as a test says: one answer for every request, and a list of the requests it saw.
actor CannedImageTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private let status: Int
    private let body: Data
    private let failure: URLError?

    init(status: Int = 200, body: Data = AvatarFixtures.png, failure: URLError? = nil) {
        self.status = status
        self.body = body
        self.failure = failure
    }

    func send(_ request: URLRequest) throws -> (Data, URLResponse) {
        requests.append(request)
        if let failure {
            throw failure
        }
        return (body, HTTPURLResponse.make(status: status))
    }
}

/// An `AvatarDownloader` that answers as a test says, keeps the URLs it was asked for, and can hold an answer back.
actor StubAvatarDownloader: AvatarDownloader {
    private(set) var requested: [URL] = []
    private var answers: [Result<Data, AvatarError>]
    private var isHolding = false
    private var held: CheckedContinuation<Void, Never>?

    /// Answers with each of `answers` in turn, and then with the last one again.
    init(_ answers: Result<Data, AvatarError>...) {
        self.answers = answers.isEmpty ? [.success(AvatarFixtures.png)] : answers
    }

    func holdNextDownload() {
        isHolding = true
    }

    func waitForHeldDownload() async {
        while held == nil {
            await Task.yield()
        }
    }

    func releaseDownload() {
        held?.resume()
        held = nil
    }

    func image(at url: URL) async throws -> Data {
        requested.append(url)
        if isHolding {
            isHolding = false
            await withCheckedContinuation { held = $0 }
        }
        let answer = answers.count > 1 ? answers.removeFirst() : answers[0]
        return try answer.get()
    }
}
