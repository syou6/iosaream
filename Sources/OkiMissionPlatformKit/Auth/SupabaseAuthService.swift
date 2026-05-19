import Foundation
import OkiMissionCore
import OkiMissionServices

// Bridges Sign in with Apple credentials to Supabase auth via the
// supabase-swift client. Requires the supabase-swift SPM dependency.

#if canImport(Supabase) && os(iOS)
import Supabase

public actor SupabaseAuthService: AuthServicing {
    private let client: SupabaseClient
    private var cachedSession: AuthSession?
    private let continuation: AsyncStream<AuthEvent>.Continuation
    public nonisolated let events: AsyncStream<AuthEvent>
    private var listenerTask: Task<Void, Never>?

    public init(supabaseURL: URL, supabaseAnonKey: String) {
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseAnonKey)
        let (stream, continuation) = AsyncStream.makeStream(of: AuthEvent.self)
        self.events = stream
        self.continuation = continuation
    }

    public var currentSession: AuthSession? {
        get async { cachedSession }
    }

    public func bootstrap() async {
        if let session = try? await client.auth.session {
            cachedSession = Self.translate(session: session)
        }
        listenerTask = Task { [weak self] in
            guard let self else { return }
            for await change in client.auth.authStateChanges {
                await self.handle(change: change)
            }
        }
    }

    public func signInWithApple(identityToken: String, nonce: String) async throws -> AuthSession {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: identityToken, nonce: nonce)
            )
            let translated = Self.translate(session: session)
            cachedSession = translated
            continuation.yield(.signedIn(translated))
            return translated
        } catch {
            throw AuthError.providerFailure(error.localizedDescription)
        }
    }

    public func refreshSession() async throws -> AuthSession {
        do {
            let session = try await client.auth.refreshSession()
            let translated = Self.translate(session: session)
            cachedSession = translated
            continuation.yield(.sessionRefreshed(translated))
            return translated
        } catch {
            throw AuthError.providerFailure(error.localizedDescription)
        }
    }

    public func signOut() async throws {
        do {
            try await client.auth.signOut()
            cachedSession = nil
            continuation.yield(.signedOut)
        } catch {
            throw AuthError.providerFailure(error.localizedDescription)
        }
    }

    public func deleteAccount() async throws {
        struct DeleteResponse: Decodable { let ok: Bool }
        do {
            _ = try await client.functions.invoke(
                "account-delete",
                options: .init(method: .post)
            )
            cachedSession = nil
            continuation.yield(.deletionCompleted)
        } catch {
            throw AuthError.providerFailure(error.localizedDescription)
        }
    }

    private func handle(change: AuthChangeEvent) async {
        switch change {
        case .signedOut:
            cachedSession = nil
            continuation.yield(.signedOut)
        case .tokenRefreshed, .signedIn, .userUpdated:
            if let session = try? await client.auth.session {
                let translated = Self.translate(session: session)
                cachedSession = translated
                continuation.yield(.sessionRefreshed(translated))
            }
        default:
            break
        }
    }

    private static func translate(session: Session) -> AuthSession {
        AuthSession(
            userId: session.user.id.uuidString,
            email: session.user.email,
            displayName: session.user.userMetadata["display_name"]?.stringValue,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: session.expiresAt.map { Date(timeIntervalSince1970: $0) }
        )
    }
}
#endif
