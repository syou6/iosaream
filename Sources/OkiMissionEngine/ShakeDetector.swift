import Foundation
import OkiMissionCore

public final class ShakeDetector {
    private let minMagnitude: Double
    private let cooldownSeconds: TimeInterval
    private var lastShakeAt: TimeInterval = -.infinity
    public private(set) var shakeCount: Int = 0

    public init(minMagnitude: Double = 1.8, cooldownSeconds: TimeInterval = 0.4) {
        self.minMagnitude = minMagnitude
        self.cooldownSeconds = cooldownSeconds
    }

    @discardableResult
    public func consume(_ sample: AccelerationSample) -> Bool {
        let magnitude = sample.magnitude
        guard magnitude >= minMagnitude else { return false }
        guard sample.timestamp - lastShakeAt >= cooldownSeconds else { return false }
        lastShakeAt = sample.timestamp
        shakeCount += 1
        return true
    }

    public func reset() {
        shakeCount = 0
        lastShakeAt = -.infinity
    }
}
