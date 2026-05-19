import Foundation
import OkiMissionCore

public enum MotionError: Error, Sendable, Equatable {
    case unavailable
    case unauthorized
}

public protocol MotionSensing: Sendable {
    func start(updateInterval: TimeInterval) async throws
    func stop() async
    var samples: AsyncStream<AccelerationSample> { get }
}

public actor StubMotionSensor: MotionSensing {
    private let continuation: AsyncStream<AccelerationSample>.Continuation
    public nonisolated let samples: AsyncStream<AccelerationSample>
    public private(set) var isRunning = false
    public var initialError: MotionError?

    public init(initialError: MotionError? = nil) {
        let (stream, continuation) = AsyncStream.makeStream(of: AccelerationSample.self)
        self.samples = stream
        self.continuation = continuation
        self.initialError = initialError
    }

    public func start(updateInterval: TimeInterval) async throws {
        if let error = initialError { throw error }
        isRunning = true
    }

    public func stop() async {
        isRunning = false
        continuation.finish()
    }

    public func emit(_ sample: AccelerationSample) {
        continuation.yield(sample)
    }
}
