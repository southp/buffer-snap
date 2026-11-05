import BufferSnapCore
import Foundation
import Testing

/// `OAuthAuthService` handing out access tokens. `FakeBufferServer` revokes the grant if a refresh token is used twice,
/// as Buffer does, so a test that reuses one fails on the rejection.
@Suite(.timeLimit(.minutes(1)))
struct OAuthRefreshTests {
    private let oauth = OAuthFixture()

    // MARK: Deciding when to refresh

    @Test func aRestoredTokenThatsStillGoodNeedsNoNetwork() async throws {
        let service = try await oauth.makeRestoredService(lifetime: 3000)

        #expect(try await service.validAccessToken() == "access-1")
        #expect(await oauth.server.requests.isEmpty)
    }

    /// A token about to run out could expire while a request is in flight, so it's refreshed a minute early.
    @Test(arguments: [(61.0, 0), (59.0, 1)])
    func refreshesAMinuteBeforeExpiry(lifetime: TimeInterval, expectedRefreshes: Int) async throws {
        let service = try await oauth.makeRestoredService(lifetime: lifetime)

        _ = try await service.validAccessToken()

        #expect(await oauth.refreshRequests().count == expectedRefreshes)
    }

    /// A public client sends only its ID and the token, and the new token's expiry counts from now.
    @Test func refreshSendsWhatTheGuideSaysAndSavesTheResult() async throws {
        let service = try await oauth.makeRestoredService()

        #expect(try await service.validAccessToken() == "access-2")

        let expected = ["client_id": BufferOAuth.clientID, "grant_type": "refresh_token", "refresh_token": "refresh-1"]
        #expect(await oauth.server.requests == [expected])
        let saved = try #require(try oauth.store.load())
        #expect(saved.accessToken == "access-2")
        #expect(saved.refreshToken == "refresh-2")
        #expect(saved.expiresAt == oauth.clock.now.addingTimeInterval(3600))
    }

    /// The second refresh must send the token the first one returned, or the server revokes everything.
    @Test func eachRefreshUsesTheTokenFromTheLastOne() async throws {
        let service = try await oauth.makeRestoredService()

        #expect(try await service.validAccessToken() == "access-2")
        oauth.clock.advance(by: 3600)
        #expect(try await service.validAccessToken() == "access-3")
        oauth.clock.advance(by: 3600)
        #expect(try await service.validAccessToken() == "access-4")

        #expect(await oauth.refreshRequests().map { $0["refresh_token"] } == ["refresh-1", "refresh-2", "refresh-3"])
        #expect(await oauth.server.isGrantRevoked == false)
    }

    /// The same, across a relaunch: the rotated token has to come back from storage.
    @Test func aRelaunchUsesTheSavedRotatedToken() async throws {
        let firstLaunch = try await oauth.makeRestoredService()
        _ = try await firstLaunch.validAccessToken()
        oauth.clock.advance(by: 3600)

        #expect(try await oauth.makeService().validAccessToken() == "access-3")
        #expect(await oauth.server.isGrantRevoked == false)
    }

    @Test func refreshKeepsTheOldTokenIfNoNewOneComes() async throws {
        await oauth.server.omit(["refresh_token"])
        let service = try await oauth.makeRestoredService()

        #expect(try await service.validAccessToken() == "access-2")

        #expect(try oauth.store.load()?.refreshToken == "refresh-1")
    }

    @Test func aMissingLifetimeCountsAsAnHour() async throws {
        await oauth.server.omit(["expires_in"])
        let service = try await oauth.makeRestoredService()

        _ = try await service.validAccessToken()

        #expect(try oauth.store.load()?.expiresAt == oauth.clock.now.addingTimeInterval(3600))
    }

    // MARK: Serializing

    /// The rule the whole design serves. The server would revoke the grant if a second caller sent the same token.
    @Test func concurrentCallersShareOneRefresh() async throws {
        let service = try await oauth.makeRestoredService()
        await oauth.server.holdNextResponse()

        let tokens = await withTaskGroup(of: String?.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    try? await service.validAccessToken()
                }
            }
            await oauth.server.waitForHeldRequest()
            // Give every caller time to reach the service while the one request is in flight.
            for _ in 0..<200 {
                await Task.yield()
            }
            await oauth.server.releaseResponse()
            return await group.reduce(into: [String?]()) { $0.append($1) }
        }

        #expect(tokens.count == 50)
        #expect(Set(tokens) == ["access-2"])
        #expect(await oauth.refreshRequests().count == 1)
        #expect(await oauth.server.isGrantRevoked == false)
    }

    /// Every caller waiting on a refresh hears how it went, and the next call starts a new one.
    @Test func concurrentCallersAllSeeAFailedRefresh() async throws {
        let service = try await oauth.makeRestoredService()
        await oauth.server.failNextRequest(.unreachable)
        await oauth.server.holdNextResponse()

        async let first = Result { try await service.validAccessToken() }
        async let second = Result { try await service.validAccessToken() }
        await oauth.server.waitForHeldRequest()
        for _ in 0..<200 {
            await Task.yield()
        }
        await oauth.server.releaseResponse()
        let results = await [first, second]

        for result in results {
            #expect(throws: AuthError.network) {
                try result.get()
            }
        }
        #expect(await oauth.refreshRequests().count == 1)
        #expect(try await service.validAccessToken() == "access-2")
    }

    /// A cancelled caller, such as a background task out of time, must not abandon a request Buffer may have acted on:
    /// the response holds the only copy of the next refresh token.
    @Test func cancellingACallerStillSavesTheRefreshedSession() async throws {
        let service = try await oauth.makeRestoredService()
        await oauth.server.holdNextResponse()

        let caller = Task {
            try await service.validAccessToken()
        }
        await oauth.server.waitForHeldRequest()
        caller.cancel()
        await oauth.server.releaseResponse()
        _ = await caller.result

        #expect(try await service.validAccessToken() == "access-2")
        #expect(try oauth.store.load()?.refreshToken == "refresh-2")
        #expect(await oauth.refreshRequests().count == 1)
    }

    // MARK: Saving before using

    /// When a caller gets its token, the store already has the session that token belongs to.
    @Test func theNewSessionIsSavedBeforeAnyCallerGetsItsToken() async throws {
        let service = try await oauth.makeRestoredService()

        let token = try await service.validAccessToken()

        #expect(try oauth.store.load()?.accessToken == token)
    }

    /// The old refresh token is dead once Buffer has answered. So the new tokens stay in memory, no caller gets one
    /// until a save works, and no second refresh goes out with the old token.
    @Test func aFailedSaveWithholdsTheTokenAndKeepsTheRotatedOne() async throws {
        let service = try await oauth.makeRestoredService()
        oauth.store.fail(saves: true)

        await #expect(throws: AuthError.storage) {
            try await service.validAccessToken()
        }
        await #expect(throws: AuthError.storage) {
            try await service.validAccessToken()
        }
        #expect(try oauth.store.load()?.refreshToken == "refresh-1")

        oauth.store.fail()
        #expect(try await service.validAccessToken() == "access-2")
        #expect(try oauth.store.load()?.refreshToken == "refresh-2")
        #expect(await oauth.refreshRequests().count == 1)
        #expect(await oauth.server.isGrantRevoked == false)
    }
}

extension Result where Failure == any Error {
    fileprivate init(catching body: () async throws -> Success) async {
        do {
            self = .success(try await body())
        } catch {
            self = .failure(error)
        }
    }
}
