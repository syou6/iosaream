import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionServices

@Suite("SupabaseRunSyncClient")
struct SupabaseRunSyncClientTests {
    private let baseURL = URL(string: "https://example.supabase.co")!

    private func config() -> SupabaseConfiguration {
        SupabaseConfiguration(baseURL: baseURL, anonKey: "anon123")
    }

    private func makeRecord() -> MissionRunRecord {
        MissionRunRecord(
            id: UUID(uuidString: "44444444-0000-0000-0000-000000000001")!,
            missionKind: .math,
            startedAt: Date(timeIntervalSince1970: 1000),
            completedAt: Date(timeIntervalSince1970: 1015),
            outcome: .success,
            durationSeconds: 15,
            repsCompleted: 3,
            antiCheatScore: 0,
            signals: []
        )
    }

    @Test("empty input returns empty result without HTTP call")
    func emptyInput() async throws {
        let stub = StubHTTPClient()
        let client = SupabaseRunSyncClient(
            httpClient: stub,
            configuration: config(),
            userIdProvider: { "user-abc" },
            tokenProvider: { "tok" }
        )
        let result = try await client.upload(records: [])
        #expect(result.isEmpty)
        let recorded = await stub.recordedRequests
        #expect(recorded.isEmpty)
    }

    @Test("successful upload returns ids and sends auth headers")
    func successfulUpload() async throws {
        let stub = StubHTTPClient(queue: [
            .response(HTTPResponse(statusCode: 201, body: Data("[]".utf8)))
        ])
        let client = SupabaseRunSyncClient(
            httpClient: stub,
            configuration: config(),
            userIdProvider: { "user-abc" },
            tokenProvider: { "tok" }
        )
        let record = makeRecord()
        let ids = try await client.upload(records: [record])
        #expect(ids == [record.id])

        let recorded = await stub.recordedRequests
        guard let first = recorded.first else {
            Issue.record("expected request to be recorded")
            return
        }
        #expect(first.method == .post)
        #expect(first.url.absoluteString.hasSuffix("/rest/v1/mission_runs"))
        #expect(first.headers["Authorization"] == "Bearer tok")
        #expect(first.headers["apikey"] == "anon123")
        let body = first.body ?? Data()
        let bodyString = String(decoding: body, as: UTF8.self)
        #expect(bodyString.contains("\"user_id\":\"user-abc\""))
        #expect(bodyString.contains("\"mission_kind\":\"math\""))
    }

    @Test("401 surfaces as unauthorized")
    func unauthorized() async {
        let stub = StubHTTPClient(queue: [.response(HTTPResponse(statusCode: 401))])
        let client = SupabaseRunSyncClient(
            httpClient: stub,
            configuration: config(),
            userIdProvider: { "user-abc" },
            tokenProvider: { "tok" }
        )
        await #expect(throws: RemoteRunSyncError.unauthorized) {
            _ = try await client.upload(records: [makeRecord()])
        }
    }

    @Test("rate limited surfaces as rateLimited")
    func rateLimited() async {
        let stub = StubHTTPClient(queue: [.failure(.rateLimited(retryAfterSeconds: 30))])
        let client = SupabaseRunSyncClient(
            httpClient: stub,
            configuration: config(),
            userIdProvider: { "user-abc" },
            tokenProvider: { "tok" }
        )
        await #expect(throws: RemoteRunSyncError.rateLimited) {
            _ = try await client.upload(records: [makeRecord()])
        }
    }

    @Test("signals are serialised as a JSON array on the wire")
    func signalsSerialised() async throws {
        let stub = StubHTTPClient(queue: [
            .response(HTTPResponse(statusCode: 201, body: Data("[]".utf8)))
        ])
        let client = SupabaseRunSyncClient(
            httpClient: stub,
            configuration: config(),
            userIdProvider: { "user-abc" },
            tokenProvider: { "tok" }
        )
        var record = makeRecord()
        record.signals = [.backgrounded(count: 2), .tooFast(durationSeconds: 5)]
        _ = try await client.upload(records: [record])

        let recorded = await stub.recordedRequests
        let body = recorded.first?.body ?? Data()
        let json = String(decoding: body, as: UTF8.self)
        #expect(json.contains("\"signals\""))
        #expect(json.contains("backgrounded"))
        #expect(json.contains("tooFast"))
    }
}
