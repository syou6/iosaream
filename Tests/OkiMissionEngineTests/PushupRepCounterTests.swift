import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionEngine

final class StubClock: AppClock, @unchecked Sendable {
    var current: TimeInterval = 0
    func now() -> Date { Date(timeIntervalSince1970: current) }
    func uptime() -> TimeInterval { current }
    func advance(_ seconds: TimeInterval) { current += seconds }
}

@Suite("PushupRepCounter")
struct PushupRepCounterTests {
    @Test("low confidence emits lowConfidence event")
    func lowConfidence() {
        let counter = PushupRepCounter(config: .default, clock: StubClock())
        let event = counter.consume(elbowAngle: 90, leftConfidence: 0.1, rightConfidence: 0.2)
        #expect(event == .lowConfidence)
    }

    @Test("up to down transitions phase")
    func upToDown() {
        let counter = PushupRepCounter(config: .default, clock: StubClock())
        let event = counter.consume(elbowAngle: 80, leftConfidence: 0.9, rightConfidence: 0.9)
        #expect(event == .phaseChanged(.down))
        #expect(counter.phase == .down)
        #expect(counter.repCount == 0)
    }

    @Test("down to up with sufficient duration completes a rep")
    func completeRep() {
        let clock = StubClock()
        let counter = PushupRepCounter(config: .default, clock: clock)

        _ = counter.consume(elbowAngle: 70, leftConfidence: 0.9, rightConfidence: 0.9)
        clock.advance(1.0)
        let event = counter.consume(elbowAngle: 170, leftConfidence: 0.9, rightConfidence: 0.9)

        guard case let .repCompleted(count, duration) = event else {
            Issue.record("expected repCompleted, got \(String(describing: event))")
            return
        }
        #expect(count == 1)
        #expect(duration >= 1.0)
        #expect(counter.phase == .up)
        #expect(counter.repCount == 1)
    }

    @Test("too-fast rep is rejected")
    func tooFastRejected() {
        let clock = StubClock()
        let counter = PushupRepCounter(config: .default, clock: clock)

        _ = counter.consume(elbowAngle: 70, leftConfidence: 0.9, rightConfidence: 0.9)
        clock.advance(0.3)
        let event = counter.consume(elbowAngle: 170, leftConfidence: 0.9, rightConfidence: 0.9)

        #expect(event == .repRejectedTooFast)
        #expect(counter.repCount == 0)
        #expect(counter.phase == .up)
    }

    @Test("mid-range angles emit nil event")
    func midRangeIgnored() {
        let counter = PushupRepCounter(config: .default, clock: StubClock())
        let event = counter.consume(elbowAngle: 120, leftConfidence: 0.9, rightConfidence: 0.9)
        #expect(event == nil)
    }

    @Test("multiple reps accumulate count")
    func multipleReps() {
        let clock = StubClock()
        let counter = PushupRepCounter(config: .default, clock: clock)

        for _ in 0..<5 {
            _ = counter.consume(elbowAngle: 70, leftConfidence: 0.9, rightConfidence: 0.9)
            clock.advance(1.0)
            _ = counter.consume(elbowAngle: 170, leftConfidence: 0.9, rightConfidence: 0.9)
            clock.advance(0.2)
        }

        #expect(counter.repCount == 5)
    }
}
