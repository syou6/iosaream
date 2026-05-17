import Foundation
import OkiMissionCore
import OkiMissionServices

#if canImport(CoreMotion) && os(iOS)
import CoreMotion

public final class CoreMotionSensor: MotionSensing, @unchecked Sendable {
    private let manager = CMMotionManager()
    private let continuation: AsyncStream<AccelerationSample>.Continuation
    public let samples: AsyncStream<AccelerationSample>
    private let queue: OperationQueue

    public init() {
        let (stream, continuation) = AsyncStream.makeStream(of: AccelerationSample.self)
        self.samples = stream
        self.continuation = continuation
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        self.queue = queue
    }

    public func start(updateInterval: TimeInterval) async throws {
        guard manager.isDeviceMotionAvailable else {
            throw MotionError.unavailable
        }
        manager.deviceMotionUpdateInterval = updateInterval
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self, let motion else { return }
            let accel = motion.userAcceleration
            let sample = AccelerationSample(
                x: accel.x,
                y: accel.y,
                z: accel.z,
                timestamp: motion.timestamp
            )
            self.continuation.yield(sample)
        }
    }

    public func stop() async {
        manager.stopDeviceMotionUpdates()
        continuation.finish()
    }
}
#endif
