import BufferSnapCore
import Foundation
import Synchronization

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

/// Buffer's API as a queue test needs it: it keeps the ideas it was asked to create, and fails as a test says.
actor FakeIdeasServer: HTTPTransport {
    enum Fault: Sendable {
        /// The request never arrives.
        case offline
        /// Buffer does the work, but the response never comes back.
        case responseLost
        /// Buffer answers this instead of doing the work.
        case answer(CannedAnswer)
        /// Buffer does the work, and then answers this.
        case answerAfterWork(CannedAnswer)
    }

    struct Idea: Sendable, Equatable {
        let text: String
        let organizationID: String
    }

    private(set) var ideas: [Idea] = []
    private(set) var organizationRequests = 0
    private(set) var ideaRequests = 0
    private var organizations = ["org-1", "org-2"]
    private var ideaFaults: [Fault] = []
    private var organizationFaults: [Fault] = []
    private var isHoldingNextIdea = false
    private var heldIdea: CheckedContinuation<Void, Never>?
    private var onIdea: (@Sendable () async -> Void)?

    var ideaTexts: [String] {
        ideas.map(\.text)
    }

    /// Fails the next idea requests with these, in order.
    func failIdeas(_ faults: Fault...) {
        ideaFaults += faults
    }

    /// Fails the next organization requests with these, in order.
    func failOrganizations(_ faults: Fault...) {
        organizationFaults += faults
    }

    func setOrganizations(_ organizations: [String]) {
        self.organizations = organizations
    }

    /// Holds the next idea request before doing the work, until `releaseIdea()`.
    func holdNextIdea() {
        isHoldingNextIdea = true
    }

    func releaseIdea() {
        heldIdea?.resume()
        heldIdea = nil
    }

    func waitForHeldIdea() async {
        while heldIdea == nil {
            await Task.yield()
        }
    }

    func setOnIdea(_ action: @escaping @Sendable () async -> Void) {
        onIdea = action
    }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        if (body?["query"] as? String)?.contains("createIdea") == true {
            return try await createIdea(body: body)
        }
        organizationRequests += 1
        let fault = organizationFaults.isEmpty ? nil : organizationFaults.removeFirst()
        let list = organizations.map { #"{"id":"\#($0)"}"# }.joined(separator: ",")
        let success = #"{"data":{"account":{"organizations":[\#(list)]}}}"#
        return try respond(fault: fault, success: success)
    }

    private func createIdea(body: [String: Any]?) async throws -> (Data, URLResponse) {
        ideaRequests += 1
        if isHoldingNextIdea {
            isHoldingNextIdea = false
            await withCheckedContinuation { heldIdea = $0 }
        }
        await onIdea?()
        let fault = ideaFaults.isEmpty ? nil : ideaFaults.removeFirst()
        if case .offline = fault {
            throw URLError(.notConnectedToInternet)
        }
        if case .answer(let answer) = fault {
            return respond(answer)
        }
        let variables = body?["variables"] as? [String: Any]
        let input = variables?["input"] as? [String: Any]
        let content = input?["content"] as? [String: Any]
        ideas.append(
            Idea(
                text: content?["text"] as? String ?? "",
                organizationID: input?["organizationId"] as? String ?? ""
            ))
        return try respond(fault: fault, success: #"{"data":{"createIdea":{"__typename":"Idea"}}}"#)
    }

    private func respond(fault: Fault?, success: String) throws -> (Data, URLResponse) {
        switch fault {
        case .offline:
            throw URLError(.notConnectedToInternet)
        case .responseLost:
            throw URLError(.networkConnectionLost)
        case .answer(let answer), .answerAfterWork(let answer):
            return respond(answer)
        case nil:
            return respond(CannedAnswer(body: success))
        }
    }

    private func respond(_ answer: CannedAnswer) -> (Data, URLResponse) {
        (Data(answer.body.utf8), HTTPURLResponse.make(status: answer.status, headers: answer.headers))
    }
}

extension CannedAnswer {
    static let serverError = CannedAnswer(status: 500, body: "Oops")
    static let invalidInput = CannedAnswer(
        body: #"{"data":{"createIdea":{"__typename":"InvalidInputError","message":"No"}}}"#
    )
    static let tokenRejected = CannedAnswer(
        status: 401,
        body: #"{"errors":[{"extensions":{"code":"UNAUTHENTICATED"}}]}"#
    )

    static func tooManyRequests(retryAfter: Int?) -> CannedAnswer {
        CannedAnswer(
            status: 429,
            headers: retryAfter.map { ["Retry-After": String($0)] } ?? [:],
            body: #"{"errors":[{"extensions":{"code":"RATE_LIMIT_EXCEEDED","window":"15m"}}]}"#
        )
    }
}

/// A `SubmissionClock` whose sleeps end when a test says so, and which keeps how long each one was.
final class ManualSubmissionClock: SubmissionClock {
    private struct State {
        var now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        var sleeps: [TimeInterval] = []
        var woken = 0
    }

    private let state = Mutex(State())

    var now: Date {
        state.withLock { $0.now }
    }

    /// How long each sleep so far was, including any still going.
    var sleeps: [TimeInterval] {
        state.withLock { $0.sleeps }
    }

    func advance(by seconds: TimeInterval) {
        state.withLock { $0.now = $0.now.addingTimeInterval(seconds) }
    }

    /// Returns once `count` sleeps have started, and how long the last was.
    func waitForSleep(number count: Int) async -> TimeInterval? {
        while sleeps.count < count {
            await Task.yield()
        }
        return sleeps[count - 1]
    }

    /// Moves the clock past the latest sleep and ends it.
    func finishLatestSleep() {
        state.withLock { state in
            state.now = state.now.addingTimeInterval(state.sleeps.last ?? 0)
            state.woken = state.sleeps.count
        }
    }

    func sleep(for seconds: TimeInterval) async throws {
        let ticket = state.withLock { state in
            state.sleeps.append(seconds)
            return state.sleeps.count
        }
        while state.withLock({ $0.woken < ticket }) {
            try await Task.sleep(for: .milliseconds(1))
        }
    }
}

/// A `CaptureStore` over an in-memory one whose status and batch writes can be made to fail.
actor FlakyStatusCaptureStore: CaptureStore {
    let base: InMemoryCaptureStore
    private var isFailingStatusWrites = false
    private var isFailingBatchWrites = false

    init(seed: [Capture]) {
        base = InMemoryCaptureStore(seed: seed)
    }

    func failStatusWrites(_ isFailing: Bool) {
        isFailingStatusWrites = isFailing
    }

    func failBatchWrites(_ isFailing: Bool) {
        isFailingBatchWrites = isFailing
    }

    func all() async throws -> [Capture] {
        await base.all()
    }

    func add(_ capture: Capture) async throws {
        await base.add(capture)
    }

    func delete(id: Capture.ID) async throws {
        await base.delete(id: id)
    }

    func setStatus(_ status: Capture.Status, failure: Capture.Failure?, ids: Set<Capture.ID>) async throws {
        if isFailingStatusWrites {
            throw TestError()
        }
        await base.setStatus(status, failure: failure, ids: ids)
    }

    func assignBatches(_ batchIDs: [Capture.ID: Capture.BatchID]) async throws {
        if isFailingBatchWrites {
            throw TestError()
        }
        await base.assignBatches(batchIDs)
    }
}

/// A `CaptureStore` that runs a hook once, the first time a read finds nothing pending, before returning that read.
actor StoreWithHookOnEmptyRead: CaptureStore {
    let base: InMemoryCaptureStore
    private var hook: (@Sendable () async -> Void)?

    init(seed: [Capture]) {
        base = InMemoryCaptureStore(seed: seed)
    }

    func setHook(_ hook: @escaping @Sendable () async -> Void) {
        self.hook = hook
    }

    func all() async throws -> [Capture] {
        let captures = await base.all()
        if let hook, !captures.contains(where: { $0.status == .pending }) {
            self.hook = nil
            await hook()
        }
        return captures
    }

    func add(_ capture: Capture) async throws {
        await base.add(capture)
    }

    func delete(id: Capture.ID) async throws {
        await base.delete(id: id)
    }

    func setStatus(_ status: Capture.Status, failure: Capture.Failure?, ids: Set<Capture.ID>) async throws {
        await base.setStatus(status, failure: failure, ids: ids)
    }

    func assignBatches(_ batchIDs: [Capture.ID: Capture.BatchID]) async throws {
        await base.assignBatches(batchIDs)
    }
}

/// What a queue test needs. The jitter is zero, so waits can be checked exactly.
struct QueueFixture {
    let server = FakeIdeasServer()
    let clock = ManualSubmissionClock()

    func makeQueue(
        store: any CaptureStore,
        auth: any AuthService = StubAuthService(hasSavedSession: true),
        window: TimeInterval = 0
    ) -> SubmissionQueue {
        makeQueue(store: store, auth: auth, planner: SubmissionPlanner { window })
    }

    func makeQueue(
        store: any CaptureStore,
        auth: any AuthService = StubAuthService(hasSavedSession: true),
        planner: SubmissionPlanner
    ) -> SubmissionQueue {
        SubmissionQueue(
            store: store,
            auth: auth,
            client: GraphQLBufferClient(transport: server),
            planner: planner,
            clock: clock,
            jitter: { 0 }
        )
    }
}

extension Capture {
    /// A pending text capture, made `seconds` after a fixed date.
    static func text(_ text: String, at seconds: TimeInterval = 0, batch: Capture.BatchID? = nil) -> Capture {
        Capture(kind: .text, createdAt: Date(timeIntervalSinceReferenceDate: seconds), text: text, batchID: batch)
    }
}
