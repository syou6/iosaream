import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionEngine

@Suite("ShakeDetector")
struct ShakeDetectorTests {
    @Test("sample below threshold is ignored")
    func belowThresholdIgnored() {
        let detector = ShakeDetector(minMagnitude: 2.0, cooldownSeconds: 0.4)
        let triggered = detector.consume(AccelerationSample(x: 0.5, y: 0.5, z: 0.5, timestamp: 1.0))
        #expect(!triggered)
        #expect(detector.shakeCount == 0)
    }

    @Test("strong sample increments count")
    func strongIncrements() {
        let detector = ShakeDetector(minMagnitude: 2.0, cooldownSeconds: 0.4)
        let triggered = detector.consume(AccelerationSample(x: 2.0, y: 0, z: 0, timestamp: 1.0))
        #expect(triggered)
        #expect(detector.shakeCount == 1)
    }

    @Test("cooldown rejects subsequent shake within window")
    func cooldownRejects() {
        let detector = ShakeDetector(minMagnitude: 2.0, cooldownSeconds: 0.4)
        _ = detector.consume(AccelerationSample(x: 3, y: 0, z: 0, timestamp: 1.0))
        let second = detector.consume(AccelerationSample(x: 3, y: 0, z: 0, timestamp: 1.2))
        #expect(!second)
        #expect(detector.shakeCount == 1)
    }

    @Test("counts multiple distinct shakes")
    func multipleShakes() {
        let detector = ShakeDetector(minMagnitude: 2.0, cooldownSeconds: 0.4)
        _ = detector.consume(AccelerationSample(x: 3, y: 0, z: 0, timestamp: 1.0))
        _ = detector.consume(AccelerationSample(x: 3, y: 0, z: 0, timestamp: 1.5))
        _ = detector.consume(AccelerationSample(x: 3, y: 0, z: 0, timestamp: 2.0))
        #expect(detector.shakeCount == 3)
    }

    @Test("reset zeroes counter and cooldown")
    func resetWorks() {
        let detector = ShakeDetector(minMagnitude: 2.0, cooldownSeconds: 0.4)
        _ = detector.consume(AccelerationSample(x: 3, y: 0, z: 0, timestamp: 1.0))
        detector.reset()
        #expect(detector.shakeCount == 0)
        let now = detector.consume(AccelerationSample(x: 3, y: 0, z: 0, timestamp: 1.1))
        #expect(now)
    }
}
