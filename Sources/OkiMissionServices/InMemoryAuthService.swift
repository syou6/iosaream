import Foundation
import OkiMissionCore

public actor InMemoryAuthService: AuthServicing {
    private var session: AuthSession?
    private let continuation: AsyncStream<AuthEvent>.Continuation
    public nonisolated let events: AsyncStream<AuthEvent>

    public init(session: AuthSession? = nil) {
        self.session = session
        let (stream, continuation) = AsyncStream.makeStream(of: AuthEvent.self)
        self.events = stream
        self.continuation = continuation
    }

    public var currentSession: AuthSession? {
        get async { session }
    }

    public func signInWithApple(identityToken: String, nonce: String) async throws -> AuthSession {
        let newSession = AuthSession(
            userId: "user_" + identityToken.suffix(8),
            email: nil,
            displayName: nil,
            accessToken: UUID().uuidString,
            refreshToken: UUID().uuidString,
            expiresAt: Date(timeIntervalSinceNow: 3600)
        )
        session = newSession
        continuation.yield(.signedIn(newSession))
        return newSession
    }

    public func refreshSession() async throws -> AuthSession {
        guard var current = session else {
            throw AuthError.notAuthenticated
        }
        current.accessToken = UUID().uuidString
        current.expiresAt = Date(timeIntervalSinceNow: 3600)
        session = current
        continuation.yield(.sessionRefreshed(current))
        return current
    }

    public func signOut() async throws {
        session = nil
        continuation.yield(.signedOut)
    }

    public func deleteAccount() async throws {
        session = nil
        continuation.yield(.deletionCompleted)
    }

    public func injectSession(_ newSession: AuthSession?) {
        session = newSession
        if let s = newSession {
            continuation.yield(.signedIn(s))
        } else {
            continuation.yield(.signedOut)
        }
    }
}
