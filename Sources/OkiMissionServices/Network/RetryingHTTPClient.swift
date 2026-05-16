import Foundation

public struct RetryPolicy: Sendable, Equatable {
    public var maxAttempts: Int
    public var baseDelay: TimeInterval
    public var maxDelay: TimeInterval
    public var jitterFactor: Double

    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 2,
        maxDelay: TimeInterval = 16,
        jitterFactor: Double = 0.2
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitterFactor = max(0, jitterFactor)
    }

    public static let `default` = RetryPolicy()
    public static let none = RetryPolicy(maxAttempts: 1, baseDelay: 0, maxDelay: 0, jitterFactor: 0)

    public func delay(forAttempt attempt: Int, jitter: Double = .random(in: 0...1)) -> TimeInterval {
        let backoff = baseDelay * pow(2.0, Double(attempt - 1))
        let capped = min(maxDelay, backoff)
        let spread = capped * jitterFactor
        return capped + spread * (jitter * 2 - 1)
    }
}

public protocol AsyncSleeper: Sendable {
    func sleep(seconds: TimeInterval) async throws
}

public struct TaskSleeper: AsyncSleeper {
    public init() {}
    public func sleep(seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

public struct RetryingHTTPClient: HTTPClient {
    private let inner: any HTTPClient
    private let policy: RetryPolicy
    private let sleeper: any AsyncSleeper

    public init(
        inner: any HTTPClient,
        policy: RetryPolicy = .default,
        sleeper: any AsyncSleeper = TaskSleeper()
    ) {
        self.inner = inner
        self.policy = policy
        self.sleeper = sleeper
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var attempt = 0
        var lastError: HTTPError = .retriesExhausted
        while attempt < policy.maxAttempts {
            attempt += 1
            do {
                let response = try await inner.send(request)
                if response.isRetryable, attempt < policy.maxAttempts {
                    try await sleeper.sleep(seconds: policy.delay(forAttempt: attempt))
                    lastError = .server(statusCode: response.statusCode)
                    continue
                }
                if response.isSuccess {
                    return response
                }
                throw HTTPError.server(statusCode: response.statusCode)
            } catch let error as HTTPError {
                switch error {
                case .timeout, .transport, .rateLimited:
                    lastError = error
                    if attempt < policy.maxAttempts {
                        let extra: TimeInterval
                        if case .rateLimited(let retry) = error, let retry { extra = retry } else { extra = 0 }
                        try await sleeper.sleep(seconds: policy.delay(forAttempt: attempt) + extra)
                        continue
                    }
                    throw error
                default:
                    throw error
                }
            }
        }
        throw lastError
    }
}
