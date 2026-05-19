import Foundation
import OkiMissionCore

public final class ShakeMissionEngine {
    public let requiredShakes: Int
    private let detector: ShakeDetector

    public init(params: ShakeParams) {
        self.requiredShakes = max(1, params.requiredShakes)
        self.detector = ShakeDetector(minMagnitude: params.minMagnitude)
    }

    @discardableResult
    public func consume(_ sample: AccelerationSample) -> Bool {
        detector.consume(sample)
    }

    public var completedShakes: Int { detector.shakeCount }
    public var isComplete: Bool { completedShakes >= requiredShakes }
    public var progress: Double {
        Double(completedShakes) / Double(requiredShakes)
    }

    public func reset() {
        detector.reset()
    }
}
