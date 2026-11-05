import BufferSnapCore
import Foundation

/// One answer from a `CannedTransport`.
struct CannedAnswer: Sendable {
    var status = 200
    var headers: [String: String] = [:]
    var body = ""
    var failure: URLError?

    init(status: Int = 200, headers: [String: String] = [:], body: String = "") {
        self.status = status
        self.headers = headers
        self.body = body
    }

    init(failure: URLError) {
        self.failure = failure
    }
}

/// An `HTTPTransport` that always gives the same answer, and keeps the requests it saw.
actor CannedTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private let answer: CannedAnswer

    init(_ answer: CannedAnswer) {
        self.answer = answer
    }

    func send(_ request: URLRequest) throws -> (Data, URLResponse) {
        requests.append(request)
        if let failure = answer.failure {
            throw failure
        }
        return (Data(answer.body.utf8), HTTPURLResponse.make(status: answer.status, headers: answer.headers))
    }
}

extension HTTPURLResponse {
    static func make(status: Int, headers: [String: String] = [:]) -> URLResponse {
        let url = URL(fileURLWithPath: "/")
        return HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers) ?? URLResponse()
    }
}
