import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionServices

@Suite("InMemoryAuthService")
struct InMemoryAuthServiceTests {
    @Test("starts unauthenticated")
    func startsUnauthenticated() async {
        let service = InMemoryAuthService()
        let session = await service.currentSession
        #expect(session == nil)
    }

    @Test("signInWithApple establishes a session")
    func signInEstablishesSession() async throws {
        let service = InMemoryAuthService()
        let session = try await service.signInWithApple(identityToken: "abcd1234efgh5678", nonce: "n")
        #expect(session.accessToken.isEmpty == false)
        let current = await service.currentSession
        #expect(current?.userId == session.userId)
    }

    @Test("signOut clears session")
    func signOutClears() async throws {
        let service = InMemoryAuthService()
        _ = try await service.signInWithApple(identityToken: "id12345678", nonce: "n")
        try await service.signOut()
        let current = await service.currentSession
        #expect(current == nil)
    }

    @Test("refresh fails when not authenticated")
    func refreshFailsWhenSignedOut() async {
        let service = InMemoryAuthService()
        await #expect(throws: AuthError.notAuthenticated) {
            _ = try await service.refreshSession()
        }
    }

    @Test("refresh issues a new token")
    func refreshIssuesNewToken() async throws {
        let service = InMemoryAuthService()
        let initial = try await service.signInWithApple(identityToken: "id12345678", nonce: "n")
        let refreshed = try await service.refreshSession()
        #expect(refreshed.userId == initial.userId)
        #expect(refreshed.accessToken != initial.accessToken)
    }
}
