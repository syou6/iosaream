import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionServices

@Suite("SupabaseProfileSyncClient")
struct SupabaseProfileSyncClientTests {
    private let baseURL = URL(string: "https://example.supabase.co")!

    private func config() -> SupabaseConfiguration {
        SupabaseConfiguration(baseURL: baseURL, anonKey: "anon123")
    }

    @Test("empty snapshot does not call HTTP")
    func emptySnapshot() async throws {
        let stub = StubHTTPClient()
        let client = SupabaseProfileSyncClient(
            httpClient: stub,
            configuration: config(),
            userIdProvider: { "user-abc" },
            tokenProvider: { "tok" }
        )
        try await client.push(RemoteProfileSnapshot())
        let recorded = await stub.recordedRequests
        #expect(recorded.isEmpty)
    }

    @Test("apns token push uses PATCH with eq filter")
    func apnsTokenPush() async throws {
        let stub = StubHTTPClient(queue: [.response(HTTPResponse(statusCode: 204))])
        let client = SupabaseProfileSyncClient(
            httpClient: stub,
            configuration: config(),
            userIdProvider: { "user-abc" },
            tokenProvider: { "tok" }
        )
        try await client.push(RemoteProfileSnapshot(
            apnsToken: "deadbeef",
            apnsEnv: .production
        ))
        let recorded = await stub.recordedRequests
        guard let first = recorded.first else {
            Issue.record("expected request")
            return
        }
        #expect(first.method == .patch)
        #expect(first.url.absoluteString.contains("/rest/v1/profiles"))
        #expect(first.url.absoluteString.contains("id=eq.user-abc"))
        let body = String(decoding: first.body ?? Data(), as: UTF8.self)
        #expect(body.contains("\"apns_token\":\"deadbeef\""))
        #expect(body.contains("\"apns_env\":\"production\""))
        #expect(!body.contains("display_name"))
    }

    @Test("401 surfaces as unauthorized")
    func unauthorized() async {
        let stub = StubHTTPClient(queue: [.response(HTTPResponse(statusCode: 401))])
        let client = SupabaseProfileSyncClient(
            httpClient: stub,
            configuration: config(),
            userIdProvider: { "user-abc" },
            tokenProvider: { "tok" }
        )
        await #expect(throws: RemoteProfileSyncError.unauthorized) {
            try await client.push(RemoteProfileSnapshot(displayName: "name"))
        }
    }

    @Test("display name and locale push without optional fields")
    func partialFields() async throws {
        let stub = StubHTTPClient(queue: [.response(HTTPResponse(statusCode: 204))])
        let client = SupabaseProfileSyncClient(
            httpClient: stub,
            configuration: config(),
            userIdProvider: { "user-abc" },
            tokenProvider: { "tok" }
        )
        try await client.push(RemoteProfileSnapshot(
            displayName: "Yamada",
            preferredLocale: "ja-JP"
        ))
        let recorded = await stub.recordedRequests
        let body = String(decoding: recorded.first?.body ?? Data(), as: UTF8.self)
        #expect(body.contains("\"display_name\":\"Yamada\""))
        #expect(body.contains("\"preferred_locale\":\"ja-JP\""))
        #expect(!body.contains("apns_token"))
    }

    @Test("missing user id surfaces as missingUser")
    func missingUser() async {
        let stub = StubHTTPClient()
        let client = SupabaseProfileSyncClient(
            httpClient: stub,
            configuration: config(),
            userIdProvider: { throw RemoteProfileSyncError.missingUser },
            tokenProvider: { "tok" }
        )
        await #expect(throws: RemoteProfileSyncError.missingUser) {
            try await client.push(RemoteProfileSnapshot(displayName: "n"))
        }
    }
}
