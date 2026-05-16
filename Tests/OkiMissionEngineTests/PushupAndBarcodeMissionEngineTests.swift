import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionEngine

@Suite("PushupMissionEngine")
struct PushupMissionEngineTests {
    @Test("starts at zero reps")
    func startsZero() {
        let engine = PushupMissionEngine(targetReps: 3)
        #expect(engine.completedReps == 0)
        #expect(!engine.isComplete)
    }

    @Test("counts reps via smoothed angle threshold")
    func countsReps() {
        let clock = StubClock()
        let counter = PushupRepCounter(config: .default, clock: clock)
        let engine = PushupMissionEngine(
            targetReps: 2,
            smoother: PoseSmoother(alpha: 0.5),
            counter: counter
        )

        for _ in 0..<2 {
            for _ in 0..<5 {
                _ = engine.consume(rawElbowAngle: 60, leftConfidence: 0.9, rightConfidence: 0.9)
            }
            clock.advance(1.0)
            for _ in 0..<5 {
                _ = engine.consume(rawElbowAngle: 180, leftConfidence: 0.9, rightConfidence: 0.9)
            }
            clock.advance(0.5)
        }
        #expect(engine.completedReps == 2)
        #expect(engine.isComplete)
    }
}

@Suite("BarcodeMissionEngine")
struct BarcodeMissionEngineTests {
    @Test("accepts unique payloads")
    func uniquePayloads() {
        let engine = BarcodeMissionEngine(params: BarcodeParams(targetCount: 2))
        #expect(engine.consume(payload: "AAA"))
        #expect(engine.consume(payload: "BBB"))
        #expect(engine.isComplete)
    }

    @Test("ignores duplicate payload")
    func duplicateIgnored() {
        let engine = BarcodeMissionEngine(params: BarcodeParams(targetCount: 2))
        _ = engine.consume(payload: "AAA")
        #expect(engine.consume(payload: "AAA") == false)
        #expect(!engine.isComplete)
    }
}

@Suite("ShakeMissionEngine")
struct ShakeMissionEngineTests {
    @Test("counts qualifying shakes")
    func countsShakes() {
        let engine = ShakeMissionEngine(params: ShakeParams(requiredShakes: 2, minMagnitude: 2.0))
        _ = engine.consume(AccelerationSample(x: 3, y: 0, z: 0, timestamp: 1.0))
        _ = engine.consume(AccelerationSample(x: 3, y: 0, z: 0, timestamp: 1.6))
        #expect(engine.completedShakes == 2)
        #expect(engine.isComplete)
    }

    @Test("weak shake does not increment")
    func weakShakeIgnored() {
        let engine = ShakeMissionEngine(params: ShakeParams(requiredShakes: 1, minMagnitude: 2.0))
        _ = engine.consume(AccelerationSample(x: 0.3, y: 0.2, z: 0.1, timestamp: 1.0))
        #expect(engine.completedShakes == 0)
    }
}
