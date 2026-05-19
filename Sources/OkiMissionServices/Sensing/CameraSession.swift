import Foundation

public struct CameraFrame: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let width: Int
    public let height: Int
    public let identifier: UUID

    public init(timestamp: TimeInterval, width: Int, height: Int, identifier: UUID = UUID()) {
        self.timestamp = timestamp
        self.width = width
        self.height = height
        self.identifier = identifier
    }
}

public enum CameraError: Error, Equatable, Sendable {
    case unauthorized
    case unavailable
    case interrupted
    case configurationFailed(String)
}

public protocol CameraSessioning: Sendable {
    func start() async throws
    func stop() async
    var frames: AsyncStream<CameraFrame> { get }
}

public actor StubCameraSession: CameraSessioning {
    private let continuation: AsyncStream<CameraFrame>.Continuation
    public nonisolated let frames: AsyncStream<CameraFrame>
    private(set) public var isRunning: Bool = false
    public var initialError: CameraError?

    public init(initialError: CameraError? = nil) {
        let (stream, continuation) = AsyncStream.makeStream(of: CameraFrame.self)
        self.frames = stream
        self.continuation = continuation
        self.initialError = initialError
    }

    public func start() async throws {
        if let error = initialError { throw error }
        isRunning = true
    }

    public func stop() async {
        isRunning = false
        continuation.finish()
    }

    public func emit(_ frame: CameraFrame) {
        continuation.yield(frame)
    }
}
