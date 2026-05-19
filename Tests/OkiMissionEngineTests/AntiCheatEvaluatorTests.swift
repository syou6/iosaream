import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionEngine

@Suite("AntiCheatEvaluator")
struct AntiCheatEvaluatorTests {
    @Test("clean context returns clean verdict")
    func cleanVerdict() {
        let evaluator = AntiCheatEvaluator()
        let context = AntiCheatContext(sessionStart: Date(), sessionStartUptime: 0)
        let verdict = evaluator.evaluate(context: context, kind: .pushup, durationSeconds: 30)
        #expect(verdict == .clean)
    }

    @Test("backgrounding alone does not fail threshold")
    func singleBackgroundNotFailing() {
        let evaluator = AntiCheatEvaluator()
        let context = AntiCheatContext(
            sessionStart: Date(),
            sessionStartUptime: 0,
            backgroundEvents: [Date()]
        )
        let verdict = evaluator.evaluate(context: context, kind: .pushup, durationSeconds: 30)
        #expect(verdict == .clean)
    }

    @Test("clock tampering pushes verdict to cheated")
    func clockTampering() {
        let evaluator = AntiCheatEvaluator()
        let start = Date()
        let context = AntiCheatContext(
            sessionStart: start,
            sessionStartUptime: 0,
            clockReadings: [
                .init(uptime: 0, wallClock: start),
                .init(uptime: 10, wallClock: start.addingTimeInterval(60))
            ]
        )
        let verdict = evaluator.evaluate(context: context, kind: .pushup, durationSeconds: 30)
        if case .cheated(let signals) = verdict {
            #expect(signals.contains { signal in
                if case .clockTampered = signal { return true }
                return false
            })
        } else {
            Issue.record("expected cheated verdict")
        }
    }

    @Test("too-fast completion is flagged")
    func tooFast() {
        let evaluator = AntiCheatEvaluator()
        let context = AntiCheatContext(sessionStart: Date(), sessionStartUptime: 0)
        let verdict = evaluator.evaluate(context: context, kind: .pushup, durationSeconds: 2)
        #expect(verdict != .clean)
    }

    @Test("frame gaps accumulate score")
    func frameGaps() {
        let evaluator = AntiCheatEvaluator()
        let context = AntiCheatContext(
            sessionStart: Date(),
            sessionStartUptime: 0,
            frameGapsSeconds: [1.2, 1.5, 2.0]
        )
        let verdict = evaluator.evaluate(context: context, kind: .pushup, durationSeconds: 30)
        if case .cheated(let signals) = verdict {
            #expect(signals.contains { signal in
                if case .frameGaps = signal { return true }
                return false
            })
        }
    }
}
