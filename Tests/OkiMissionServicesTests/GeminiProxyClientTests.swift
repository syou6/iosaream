import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionServices

@Suite("GeminiProxyClient")
struct GeminiProxyClientTests {
    private let baseURL = URL(string: "https://example.supabase.co")!

    private func makeResponseJSON() -> Data {
        let json = #"""
        {
          "template": {
            "kind": "pushup",
            "difficulty": "medium",
            "title": "10 pushups",
            "subtitle": "Wake up strong",
            "description": "Do 10 clean pushups",
            "encouragement": "You got this",
            "estimatedDurationSec": 60,
            "parameters": {
              "reps": 10,
              "formStrictness": "moderate",
              "maxDurationSeconds": 120
            },
            "locale": "ja-JP",
            "source": "gemini"
          },
          "ttlSec": 86400,
          "cached": false
        }
        """#
        return Data(json.utf8)
    }

    @Test("sends POST with bearer token and json body")
    func sendsCorrectRequest() async throws {
        let stub = StubHTTPClient(queue: [.response(HTTPResponse(statusCode: 200, body: makeResponseJSON()))])
        let client = GeminiProxyClient(
            httpClient: stub,
            configuration: GeminiProxyConfiguration(baseURL: baseURL, anonKey: "anon123"),
            tokenProvider: { "user-token-abc" }
        )

        _ = try await client.generate(MissionGenerationRequest(
            targetDate: Date(),
            difficultyHint: .medium,
            recentKinds: [.math],
            locale: "ja-JP"
        ))

        let requests = await stub.recordedRequests
        guard let first = requests.first else {
            Issue.record("expected a request")
            return
        }
        #expect(first.method == .post)
        #expect(first.headers["Authorization"] == "Bearer user-token-abc")
        #expect(first.headers["apikey"] == "anon123")
        #expect(first.headers["Content-Type"] == "application/json")
        #expect(first.url.path.contains("missions-generate"))
        let bodyString = String(decoding: first.body ?? Data(), as: UTF8.self)
        #expect(bodyString.contains("\"locale\":\"ja-JP\""))
        #expect(bodyString.contains("\"difficultyHint\":\"medium\""))
    }

    @Test("decodes template into domain type")
    func decodesTemplate() async throws {
        let stub = StubHTTPClient(queue: [.response(HTTPResponse(statusCode: 200, body: makeResponseJSON()))])
        let client = GeminiProxyClient(
            httpClient: stub,
            configuration: GeminiProxyConfiguration(baseURL: baseURL),
            tokenProvider: { "tok" }
        )

        let template = try await client.generate(MissionGenerationRequest(
            targetDate: Date(), difficultyHint: .medium
        ))

        #expect(template.kind == .pushup)
        #expect(template.difficulty == .medium)
        #expect(template.title == "10 pushups")
        #expect(template.encouragement == "You got this")
        #expect(template.estimatedDurationSeconds == 60)
        let params = try MissionParameterDecoder.decode(template.parametersJSON, as: PushupParams.self)
        #expect(params.reps == 10)
    }

    @Test("rate limited response surfaces as MissionGenerationError")
    func rateLimited() async {
        let stub = StubHTTPClient(queue: [.failure(.rateLimited(retryAfterSeconds: 30))])
        let client = GeminiProxyClient(
            httpClient: stub,
            configuration: GeminiProxyConfiguration(baseURL: baseURL),
            tokenProvider: { "tok" }
        )
        await #expect(throws: MissionGenerationError.rateLimited(remaining: 0)) {
            _ = try await client.generate(MissionGenerationRequest(
                targetDate: Date(), difficultyHint: .easy
            ))
        }
    }

    @Test("5xx surfaces as providerUnavailable")
    func providerUnavailable() async {
        let stub = StubHTTPClient(queue: [.response(HTTPResponse(statusCode: 500))])
        let client = GeminiProxyClient(
            httpClient: stub,
            configuration: GeminiProxyConfiguration(baseURL: baseURL),
            tokenProvider: { "tok" }
        )
        await #expect(throws: MissionGenerationError.providerUnavailable) {
            _ = try await client.generate(MissionGenerationRequest(
                targetDate: Date(), difficultyHint: .easy
            ))
        }
    }

    @Test("unknown kind in response throws decodingFailed")
    func unknownKindDecodeFails() async {
        let bogus = #"{"template":{"kind":"juggle","difficulty":"easy","title":"x","estimatedDurationSec":10,"parameters":{}}}"#
        let stub = StubHTTPClient(queue: [.response(HTTPResponse(statusCode: 200, body: Data(bogus.utf8)))])
        let client = GeminiProxyClient(
            httpClient: stub,
            configuration: GeminiProxyConfiguration(baseURL: baseURL),
            tokenProvider: { "tok" }
        )
        await #expect(throws: (any Error).self) {
            _ = try await client.generate(MissionGenerationRequest(
                targetDate: Date(), difficultyHint: .easy
            ))
        }
    }

    @Test("parameters subtree is re-serialised as sorted JSON")
    func parametersStable() async throws {
        let stub = StubHTTPClient(queue: [.response(HTTPResponse(statusCode: 200, body: makeResponseJSON()))])
        let client = GeminiProxyClient(
            httpClient: stub,
            configuration: GeminiProxyConfiguration(baseURL: baseURL),
            tokenProvider: { "tok" }
        )
        let template = try await client.generate(MissionGenerationRequest(
            targetDate: Date(), difficultyHint: .medium
        ))
        let firstKey = template.parametersJSON.split(separator: ":").first
        #expect(firstKey?.contains("formStrictness") == true)
    }
}
