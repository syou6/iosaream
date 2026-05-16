import Testing
import Foundation
@testable import OkiMissionEngine

@Suite("ObjectHuntMissionEngine")
struct ObjectHuntMissionEngineTests {
    @Test("starts with zero found")
    func startsZero() {
        let engine = ObjectHuntMissionEngine(
            targetClasses: ["a", "b", "c"], requiredCount: 2
        )
        #expect(engine.foundCount == 0)
        #expect(!engine.isComplete)
    }

    @Test("requires N confirmation frames before counting")
    func requiresConfirmationFrames() {
        let engine = ObjectHuntMissionEngine(
            targetClasses: ["book"], requiredCount: 1, confirmationFrames: 3
        )
        _ = engine.consume(detectedClasses: ["book"])
        _ = engine.consume(detectedClasses: ["book"])
        #expect(engine.foundCount == 0)
        let newly = engine.consume(detectedClasses: ["book"])
        #expect(engine.foundCount == 1)
        #expect(newly == Set(["book"]))
    }

    @Test("interrupted streak resets")
    func interruptedStreakResets() {
        let engine = ObjectHuntMissionEngine(
            targetClasses: ["book"], requiredCount: 1, confirmationFrames: 3
        )
        _ = engine.consume(detectedClasses: ["book"])
        _ = engine.consume(detectedClasses: ["book"])
        _ = engine.consume(detectedClasses: [])
        _ = engine.consume(detectedClasses: ["book"])
        _ = engine.consume(detectedClasses: ["book"])
        #expect(engine.foundCount == 0)
        _ = engine.consume(detectedClasses: ["book"])
        #expect(engine.foundCount == 1)
    }

    @Test("non-target classes are ignored")
    func nonTargetIgnored() {
        let engine = ObjectHuntMissionEngine(
            targetClasses: ["book"], requiredCount: 1, confirmationFrames: 2
        )
        _ = engine.consume(detectedClasses: ["phone", "lamp"])
        _ = engine.consume(detectedClasses: ["phone"])
        #expect(engine.foundCount == 0)
    }

    @Test("completion stops when requiredCount reached")
    func completionAtRequired() {
        let engine = ObjectHuntMissionEngine(
            targetClasses: ["a", "b", "c"], requiredCount: 2, confirmationFrames: 1
        )
        _ = engine.consume(detectedClasses: ["a"])
        _ = engine.consume(detectedClasses: ["b"])
        #expect(engine.isComplete)
        #expect(engine.foundCount == 2)
    }

    @Test("duplicate confirmation is not counted twice")
    func duplicateNotCounted() {
        let engine = ObjectHuntMissionEngine(
            targetClasses: ["book"], requiredCount: 1, confirmationFrames: 1
        )
        _ = engine.consume(detectedClasses: ["book"])
        let again = engine.consume(detectedClasses: ["book"])
        #expect(engine.foundCount == 1)
        #expect(again.isEmpty)
    }

    @Test("reset clears state")
    func resetClears() {
        let engine = ObjectHuntMissionEngine(
            targetClasses: ["a", "b"], requiredCount: 2, confirmationFrames: 1
        )
        _ = engine.consume(detectedClasses: ["a"])
        engine.reset()
        #expect(engine.foundCount == 0)
        #expect(!engine.isComplete)
    }
}
