import Foundation
import OSLog

/// Buffer's GraphQL API. A failure can arrive as an HTTP status, in the response's `errors`, or as a type in its
/// `data`, and this sorts them all into a `BufferError`.
public struct GraphQLBufferClient: BufferClient {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport) {
        self.transport = transport
    }

    public func firstOrganizationID(accessToken: String) async throws -> String {
        let query = "query Organizations { account { organizations { id } } }"
        let account: AccountData = try await send(query, variables: NoVariables(), accessToken: accessToken)
        guard let organizationID = account.account.organizations.first?.id else {
            throw BufferError.rejected(reason: "NoOrganizations")
        }
        return organizationID
    }

    public func createIdea(text: String, organizationID: String, accessToken: String) async throws {
        // `__typename` tells success from each error, including types added later. The guide asks for the `message`.
        let query = """
            mutation CreateIdea($input: CreateIdeaInput!) {
              createIdea(input: $input) {
                __typename
                ... on MutationError { message }
              }
            }
            """
        let input = CreateIdeaVariables(
            input: .init(organizationId: organizationID, content: .init(text: text))
        )
        let result: CreateIdeaData = try await send(query, variables: input, accessToken: accessToken)
        switch result.createIdea.typeName {
        case "Idea", "IdeaResponse":
            return
        case "UnexpectedError":
            throw BufferError.serverTrouble
        default:
            // Including a type this code has never heard of. Showing "Failed" is safe either way: it creates nothing
            // more unless the user asks.
            throw BufferError.rejected(reason: result.createIdea.typeName)
        }
    }

    private func send<Variables: Encodable, Payload: Decodable>(
        _ query: String,
        variables: Variables,
        accessToken: String
    ) async throws -> Payload {
        var request = URLRequest(url: BufferAPI.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(GraphQLRequest(query: query, variables: variables))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            Logger.submission.notice("Can't reach Buffer: code \((error as NSError).code, privacy: .public)")
            throw BufferError.connection
        }

        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init).flatMap {
            $0 > 0 ? $0 : nil
        }
        if !(200..<300).contains(status) {
            Logger.submission.notice("Buffer answered HTTP \(status, privacy: .public)")
        }
        switch status {
        case 401:
            throw BufferError.unauthorized
        case 429:
            throw BufferError.rateLimited(retryAfter: retryAfter)
        case 408, 500...:
            throw BufferError.serverTrouble
        default:
            break
        }

        let isSuccess = (200..<300).contains(status)
        guard let body = try? JSONDecoder().decode(GraphQLResponse<Payload>.self, from: data) else {
            // A success we can't read may have done the work. Anything else is a refusal from something.
            throw isSuccess ? BufferError.serverTrouble : BufferError.rejected(reason: "HTTP \(status)")
        }
        // Data comes first: the guide says a success can carry `errors` as warnings, and treating one as a failure
        // would send the same idea again.
        if let payload = body.data {
            return payload
        }
        guard let code = body.errors?.first?.extensions?.code else {
            throw isSuccess ? BufferError.serverTrouble : BufferError.rejected(reason: "HTTP \(status)")
        }
        throw Self.error(forCode: code, retryAfter: retryAfter)
    }

    /// Codes the guides list, plus `UNAUTHENTICATED`, which is what the API answered when probed without a token. Any
    /// other code means Buffer understood the request and refused it, such as an invalid query.
    private static func error(forCode code: String, retryAfter: Double?) -> BufferError {
        switch code {
        case "UNAUTHORIZED", "UNAUTHENTICATED":
            .unauthorized
        case "RATE_LIMIT_EXCEEDED":
            .rateLimited(retryAfter: retryAfter)
        case "UNEXPECTED", "INTERNAL_SERVER_ERROR":
            .serverTrouble
        default:
            .rejected(reason: code)
        }
    }
}

/// Where Buffer's API lives.
enum BufferAPI {
    static let endpoint: URL = {
        guard let url = URL(string: "https://api.buffer.com") else {
            preconditionFailure("Not a URL: the API endpoint")
        }
        return url
    }()
}

extension URLSession {
    /// For talking to Buffer's API: no cookies, and no cache to hold what was sent.
    public static func forBufferAPI() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }
}

// What goes over the wire. Buffer's `message` fields stay undecoded, so they can't end up in a log.

private struct GraphQLRequest<Variables: Encodable>: Encodable {
    let query: String
    let variables: Variables
}

private struct NoVariables: Encodable {}

private struct CreateIdeaVariables: Encodable {
    struct Input: Encodable {
        let organizationId: String
        let content: IdeaContent
    }

    let input: Input
}

private struct IdeaContent: Encodable {
    let text: String
}

private struct GraphQLResponse<Payload: Decodable>: Decodable {
    let data: Payload?
    let errors: [GraphQLError]?
}

private struct GraphQLError: Decodable {
    struct Extensions: Decodable {
        let code: String?
    }

    let extensions: Extensions?
}

private struct AccountData: Decodable {
    struct Account: Decodable {
        let organizations: [Organization]
    }

    struct Organization: Decodable {
        let id: String
    }

    let account: Account
}

private struct CreateIdeaData: Decodable {
    let createIdea: CreateIdeaResult
}

private struct CreateIdeaResult: Decodable {
    let typeName: String

    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
    }
}
