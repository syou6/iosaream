import Foundation
import OkiMissionCore

public struct AuthSession: Sendable, Equatable, Codable {
    public let userId: String
    public var email: String?
    public var displayName: String?
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?

    public init(
        userId: String,
        email: String? = nil,
        displayName: String? = nil,
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}

public enum AuthEvent: Sendable, Equatable {
    case signedIn(AuthSession)
    case signedOut
    case sessionRefreshed(AuthSession)
    case deletionCompleted
}

public enum AuthError: Error, Equatable, Sendable {
    case notAuthenticated
    case cancelled
    case providerFailure(String)
}

public protocol AuthServicing: Sendable {
    var currentSession: AuthSession? { get async }
    var events: AsyncStream<AuthEvent> { get }

    func signInWithApple(identityToken: String, nonce: String) async throws -> AuthSession
    func refreshSession() async throws -> AuthSession
    func signOut() async throws
    func deleteAccount() async throws
}
