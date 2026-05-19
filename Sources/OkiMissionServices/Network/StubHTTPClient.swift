import Foundation

public actor StubHTTPClient: HTTPClient {
    public enum Outcome: Sendable {
        case response(HTTPResponse)
        case failure(HTTPError)
    }

    private var queue: [Outcome]
    private let defaultOutcome: Outcome
    public private(set) var recordedRequests: [HTTPRequest] = []

    public init(queue: [Outcome] = [], default defaultOutcome: Outcome = .response(HTTPResponse(statusCode: 200))) {
        self.queue = queue
        self.defaultOutcome = defaultOutcome
    }

    public func enqueue(_ outcome: Outcome) {
        queue.append(outcome)
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        recordedRequests.append(request)
        let outcome: Outcome
        if queue.isEmpty {
            outcome = defaultOutcome
        } else {
            outcome = queue.removeFirst()
        }
        switch outcome {
        case .response(let response): return response
        case .failure(let error): throw error
        }
    }
}

public actor RecordingSleeper: AsyncSleeper {
    public private(set) var sleeps: [TimeInterval] = []

    public init() {}

    public func sleep(seconds: TimeInterval) async throws {
        sleeps.append(seconds)
    }
}
