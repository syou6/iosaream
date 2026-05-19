import Testing
import Foundation
@testable import OkiMissionServices

@Suite("RetryingHTTPClient")
struct RetryingHTTPClientTests {
    private func url() -> URL { URL(string: "https://example.com/x")! }

    @Test("successful response is returned without retry")
    func successNoRetry() async throws {
        let stub = StubHTTPClient(queue: [.response(HTTPResponse(statusCode: 200))])
        let sleeper = RecordingSleeper()
        let client = RetryingHTTPClient(inner: stub, policy: .default, sleeper: sleeper)
        let response = try await client.send(HTTPRequest(url: url()))
        #expect(response.statusCode == 200)
        let sleeps = await sleeper.sleeps
        #expect(sleeps.isEmpty)
    }

    @Test("5xx retries up to max attempts")
    func serverErrorRetries() async throws {
        let stub = StubHTTPClient(queue: [
            .response(HTTPResponse(statusCode: 500)),
            .response(HTTPResponse(statusCode: 503)),
            .response(HTTPResponse(statusCode: 200))
        ])
        let sleeper = RecordingSleeper()
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 1, maxDelay: 4, jitterFactor: 0)
        let client = RetryingHTTPClient(inner: stub, policy: policy, sleeper: sleeper)
        let response = try await client.send(HTTPRequest(url: url()))
        #expect(response.statusCode == 200)
        let sleeps = await sleeper.sleeps
        #expect(sleeps.count == 2)
    }

    @Test("non-retryable status throws server error")
    func nonRetryableThrows() async {
        let stub = StubHTTPClient(queue: [.response(HTTPResponse(statusCode: 400))])
        let sleeper = RecordingSleeper()
        let client = RetryingHTTPClient(inner: stub, policy: .default, sleeper: sleeper)
        await #expect(throws: HTTPError.server(statusCode: 400)) {
            _ = try await client.send(HTTPRequest(url: url()))
        }
        let sleeps = await sleeper.sleeps
        #expect(sleeps.isEmpty)
    }

    @Test("timeout error is retried")
    func timeoutRetried() async throws {
        let stub = StubHTTPClient(queue: [
            .failure(.timeout),
            .response(HTTPResponse(statusCode: 200))
        ])
        let sleeper = RecordingSleeper()
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 1, maxDelay: 4, jitterFactor: 0)
        let client = RetryingHTTPClient(inner: stub, policy: policy, sleeper: sleeper)
        let response = try await client.send(HTTPRequest(url: url()))
        #expect(response.statusCode == 200)
        let sleeps = await sleeper.sleeps
        #expect(sleeps.count == 1)
    }

    @Test("retries exhausted throws last error")
    func retriesExhausted() async {
        let stub = StubHTTPClient(queue: [
            .failure(.timeout),
            .failure(.timeout),
            .failure(.timeout)
        ])
        let sleeper = RecordingSleeper()
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0.1, maxDelay: 1, jitterFactor: 0)
        let client = RetryingHTTPClient(inner: stub, policy: policy, sleeper: sleeper)
        await #expect(throws: HTTPError.timeout) {
            _ = try await client.send(HTTPRequest(url: url()))
        }
    }

    @Test("backoff doubles each attempt")
    func backoffDoubles() {
        let policy = RetryPolicy(maxAttempts: 5, baseDelay: 1, maxDelay: 32, jitterFactor: 0)
        #expect(policy.delay(forAttempt: 1, jitter: 0.5) == 1)
        #expect(policy.delay(forAttempt: 2, jitter: 0.5) == 2)
        #expect(policy.delay(forAttempt: 3, jitter: 0.5) == 4)
        #expect(policy.delay(forAttempt: 4, jitter: 0.5) == 8)
    }

    @Test("backoff respects max delay cap")
    func backoffCapped() {
        let policy = RetryPolicy(maxAttempts: 10, baseDelay: 1, maxDelay: 4, jitterFactor: 0)
        #expect(policy.delay(forAttempt: 5, jitter: 0.5) == 4)
        #expect(policy.delay(forAttempt: 6, jitter: 0.5) == 4)
    }
}
