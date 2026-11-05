import BufferSnapCore
import Foundation
import Testing

/// The bodies and statuses follow Buffer's guides, except the 401, which is what the API answered when probed.
struct GraphQLBufferClientTests {
    private static let success = #"{"data":{"createIdea":{"__typename":"Idea"}}}"#

    private func createIdea(answering answer: CannedAnswer) async throws {
        let client = GraphQLBufferClient(transport: CannedTransport(answer))
        try await client.createIdea(text: "An idea", organizationID: "org-1", accessToken: "token")
    }

    private func createIdeaError(answering answer: CannedAnswer) async -> BufferError? {
        do {
            try await createIdea(answering: answer)
            return nil
        } catch {
            return error as? BufferError
        }
    }

    @Test func createIdeaSendsTheInputAsVariables() async throws {
        let transport = CannedTransport(.init(body: Self.success))
        let client = GraphQLBufferClient(transport: transport)

        try await client.createIdea(text: "An \"idea\"\nwith lines", organizationID: "org-1", accessToken: "token")

        let request = try #require(await transport.requests.first)
        #expect(request.url?.absoluteString == "https://api.buffer.com")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        let query = try #require(body["query"] as? String)
        #expect(query.contains("mutation CreateIdea($input: CreateIdeaInput!)"))
        #expect(query.contains("... on MutationError"))
        #expect(!query.contains("idea\\"), "The text travels as a variable, never inside the query")
        let variables = try #require(body["variables"] as? [String: Any])
        let input = try #require(variables["input"] as? [String: Any])
        #expect(input["organizationId"] as? String == "org-1")
        let content = try #require(input["content"] as? [String: Any])
        #expect(content["text"] as? String == "An \"idea\"\nwith lines")
        #expect(content["title"] == nil)
    }

    /// The schema's union has both success types, and the guide's example only mentions the first.
    @Test(arguments: ["Idea", "IdeaResponse"])
    func bothSuccessTypesCount(typeName: String) async throws {
        try await createIdea(answering: .init(body: #"{"data":{"createIdea":{"__typename":"\#(typeName)"}}}"#))
    }

    /// Treating these warnings as a failure would send the same idea again.
    @Test func aSuccessWithWarningsIsASuccess() async throws {
        let body = #"{"data":{"createIdea":{"__typename":"Idea"}},"errors":[{"extensions":{"code":"UNEXPECTED"}}]}"#

        try await createIdea(answering: .init(body: body))
    }

    /// These come back in `data` with a 200, so looking at the status alone would call them successes.
    @Test(arguments: [
        ("InvalidInputError", BufferError.rejected(reason: "InvalidInputError")),
        ("LimitReachedError", .rejected(reason: "LimitReachedError")),
        ("UnauthorizedError", .rejected(reason: "UnauthorizedError")),
        ("VoidMutationError", .rejected(reason: "VoidMutationError")),
        ("SomeErrorAddedNextYear", .rejected(reason: "SomeErrorAddedNextYear")),
        ("UnexpectedError", .serverTrouble),
    ])
    func mutationErrorsInDataAreFailures(typeName: String, expected: BufferError) async {
        let body = #"{"data":{"createIdea":{"__typename":"\#(typeName)","message":"Your idea: secret"}}}"#

        #expect(await createIdeaError(answering: .init(body: body)) == expected)
    }

    /// The guide's table of errors, in `errors` with a 200.
    @Test(arguments: [
        ("UNAUTHORIZED", BufferError.unauthorized),
        ("UNAUTHENTICATED", .unauthorized),
        ("FORBIDDEN", .rejected(reason: "FORBIDDEN")),
        ("NOT_FOUND", .rejected(reason: "NOT_FOUND")),
        ("UNEXPECTED", .serverTrouble),
        ("GRAPHQL_VALIDATION_FAILED", .rejected(reason: "GRAPHQL_VALIDATION_FAILED")),
    ])
    func errorCodesInA200AreSorted(code: String, expected: BufferError) async {
        let body = #"{"data":null,"errors":[{"message":"Nope","extensions":{"code":"\#(code)"}}]}"#

        #expect(await createIdeaError(answering: .init(body: body)) == expected)
    }

    /// The real API's answer to a request without a token.
    @Test func aRejectedTokenAtTheHTTPLevelIsUnauthorized() async {
        let message = "An authentication JWT or Access Token is required"
        let body = #"{"errors":[{"message":"\#(message)","extensions":{"code":"UNAUTHENTICATED"}}]}"#

        #expect(await createIdeaError(answering: .init(status: 401, body: body)) == .unauthorized)
    }

    @Test func aTooManyRequestsResponseSaysHowLongToWait() async {
        let body = #"{"errors":[{"extensions":{"code":"RATE_LIMIT_EXCEEDED","window":"15m"}}]}"#
        let answer = CannedAnswer(status: 429, headers: ["retry-after": "753"], body: body)

        #expect(await createIdeaError(answering: answer) == .rateLimited(retryAfter: 753))
    }

    @Test func aRateLimitErrorInA200AlsoCounts() async {
        let body = #"{"data":null,"errors":[{"extensions":{"code":"RATE_LIMIT_EXCEEDED"}}]}"#
        let answer = CannedAnswer(headers: ["Retry-After": "60"], body: body)

        #expect(await createIdeaError(answering: answer) == .rateLimited(retryAfter: 60))
    }

    @Test(arguments: [nil, "soon", "0", "-5"])
    func aMissingOrUselessRetryAfterIsLeftOut(retryAfter: String?) async {
        let headers = retryAfter.map { ["Retry-After": $0] } ?? [:]

        #expect(await createIdeaError(answering: .init(status: 429, headers: headers)) == .rateLimited(retryAfter: nil))
    }

    @Test(arguments: [500, 502, 503, 504, 408])
    func errorsThatMayPassAreServerTrouble(status: Int) async {
        #expect(await createIdeaError(answering: .init(status: status, body: "<html>")) == .serverTrouble)
    }

    /// A 200 that isn't Buffer's JSON, such as a Wi-Fi sign-in page, says nothing about the idea.
    @Test func aSuccessThatCantBeReadIsServerTrouble() async {
        #expect(await createIdeaError(answering: .init(body: "<html>")) == .serverTrouble)
        #expect(await createIdeaError(answering: .init(body: #"{"data":null}"#)) == .serverTrouble)
    }

    @Test(arguments: [400, 403, 404, 422])
    func otherClientErrorsAreRejected(status: Int) async {
        let error = await createIdeaError(answering: .init(status: status, body: "nope"))

        #expect(error == .rejected(reason: "HTTP \(status)"))
    }

    @Test func aFailedConnectionIsAConnectionError() async {
        let answers: [URLError.Code] = [.notConnectedToInternet, .timedOut, .networkConnectionLost, .cancelled]
        for code in answers {
            #expect(await createIdeaError(answering: .init(failure: URLError(code))) == .connection)
        }
    }

    /// Buffer's messages can repeat what was sent, so none of it may reach an error that gets logged.
    @Test func errorsDontCarryBuffersMessage() async {
        let body = #"{"data":{"createIdea":{"__typename":"InvalidInputError","message":"Your idea: secret"}}}"#

        let error = await createIdeaError(answering: .init(body: body))

        #expect(!String(describing: error).contains("secret"))
    }

    @Test func organizationsComeFromTheAccountInOrder() async throws {
        let body = #"{"data":{"account":{"organizations":[{"id":"org-1"},{"id":"org-2"}]}}}"#
        let transport = CannedTransport(.init(body: body))
        let client = GraphQLBufferClient(transport: transport)

        #expect(try await client.firstOrganizationID(accessToken: "token") == "org-1")

        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        let sent = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        #expect((sent["query"] as? String)?.contains("account { organizations { id } }") == true)
    }

    @Test func anAccountWithNoOrganizationIsRejected() async {
        let transport = CannedTransport(.init(body: #"{"data":{"account":{"organizations":[]}}}"#))
        let client = GraphQLBufferClient(transport: transport)

        await #expect(throws: BufferError.rejected(reason: "NoOrganizations")) {
            try await client.firstOrganizationID(accessToken: "token")
        }
    }

    @Test func aForbiddenOrganizationQueryIsRejected() async {
        let body = #"{"data":null,"errors":[{"extensions":{"code":"FORBIDDEN"}}]}"#
        let client = GraphQLBufferClient(transport: CannedTransport(.init(body: body)))

        await #expect(throws: BufferError.rejected(reason: "FORBIDDEN")) {
            try await client.firstOrganizationID(accessToken: "token")
        }
    }
}
