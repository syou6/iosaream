import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionEngine

@Suite("MathMissionEngine")
struct MathMissionEngineTests {
    private let problems = [
        MathProblem(lhs: 2, rhs: 3, operator: .add, answer: 5),
        MathProblem(lhs: 9, rhs: 4, operator: .subtract, answer: 5),
        MathProblem(lhs: 3, rhs: 4, operator: .multiply, answer: 12)
    ]

    @Test("starts incomplete")
    func startsIncomplete() {
        let engine = MathMissionEngine(problems: problems)
        #expect(!engine.isComplete)
        #expect(engine.correctCount == 0)
    }

    @Test("correct answer increments correct count")
    func correctAnswer() {
        let engine = MathMissionEngine(problems: problems)
        #expect(engine.submit(answer: 5, at: 0) == true)
        #expect(engine.correctCount == 1)
    }

    @Test("incorrect answer is recorded but not counted")
    func incorrectAnswer() {
        let engine = MathMissionEngine(problems: problems)
        #expect(engine.submit(answer: 7, at: 0) == false)
        #expect(engine.correctCount == 0)
        #expect(engine.answeredCount == 1)
    }

    @Test("re-submission to same index is rejected")
    func reSubmissionRejected() {
        let engine = MathMissionEngine(problems: problems)
        _ = engine.submit(answer: 7, at: 0)
        #expect(engine.submit(answer: 5, at: 0) == false)
        #expect(engine.correctCount == 0)
    }

    @Test("invalid index returns false without state change")
    func invalidIndex() {
        let engine = MathMissionEngine(problems: problems)
        #expect(engine.submit(answer: 0, at: 99) == false)
        #expect(engine.answeredCount == 0)
    }

    @Test("answering every problem makes isComplete true")
    func completionFlow() {
        let engine = MathMissionEngine(problems: problems)
        _ = engine.submit(answer: 5, at: 0)
        _ = engine.submit(answer: 5, at: 1)
        _ = engine.submit(answer: 12, at: 2)
        #expect(engine.isComplete)
        #expect(engine.isPerfect)
        #expect(engine.progress == 1.0)
    }

    @Test("partial answering yields proportional progress")
    func progressIsProportional() {
        let engine = MathMissionEngine(problems: problems)
        _ = engine.submit(answer: 5, at: 0)
        #expect(engine.progress > 0.3 && engine.progress < 0.34)
    }
}
