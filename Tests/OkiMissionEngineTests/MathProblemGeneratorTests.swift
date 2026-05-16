import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionEngine

@Suite("MathProblemGenerator")
struct MathProblemGeneratorTests {
    @Test("generates requested count")
    func generatesRequestedCount() {
        let params = MathParams(problemCount: 7, operatorTypes: [.add], minOperand: 1, maxOperand: 10)
        let gen = MathProblemGenerator(params: params)
        var rng = SeededRandom(seed: 1)
        let problems = gen.generate(using: &rng)
        #expect(problems.count == 7)
    }

    @Test("addition answer matches operands")
    func additionCorrect() {
        let params = MathParams(problemCount: 20, operatorTypes: [.add], minOperand: 1, maxOperand: 50)
        let gen = MathProblemGenerator(params: params)
        var rng = SeededRandom(seed: 42)
        for problem in gen.generate(using: &rng) {
            #expect(problem.answer == problem.lhs + problem.rhs)
        }
    }

    @Test("subtraction never produces negative answer")
    func subtractionNonNegative() {
        let params = MathParams(problemCount: 30, operatorTypes: [.subtract], minOperand: 1, maxOperand: 20)
        let gen = MathProblemGenerator(params: params)
        var rng = SeededRandom(seed: 7)
        for problem in gen.generate(using: &rng) {
            #expect(problem.answer >= 0)
            #expect(problem.answer == problem.lhs - problem.rhs)
        }
    }

    @Test("multiplication answer matches operands")
    func multiplicationCorrect() {
        let params = MathParams(problemCount: 10, operatorTypes: [.multiply], minOperand: 2, maxOperand: 9)
        let gen = MathProblemGenerator(params: params)
        var rng = SeededRandom(seed: 99)
        for problem in gen.generate(using: &rng) {
            #expect(problem.answer == problem.lhs * problem.rhs)
        }
    }

    @Test("seeded generator is deterministic")
    func seededDeterministic() {
        let params = MathParams(problemCount: 5, operatorTypes: [.add, .subtract], minOperand: 1, maxOperand: 20)
        let gen = MathProblemGenerator(params: params)
        var rng1 = SeededRandom(seed: 12345)
        var rng2 = SeededRandom(seed: 12345)
        #expect(gen.generate(using: &rng1) == gen.generate(using: &rng2))
    }

    @Test("zero count returns empty list")
    func zeroCountEmpty() {
        let params = MathParams(problemCount: 0, operatorTypes: [.add], minOperand: 1, maxOperand: 10)
        let gen = MathProblemGenerator(params: params)
        var rng = SeededRandom(seed: 1)
        #expect(gen.generate(using: &rng).isEmpty)
    }

    @Test("prompt formats operator symbol")
    func promptFormat() {
        let add = MathProblem(lhs: 3, rhs: 4, operator: .add, answer: 7)
        let sub = MathProblem(lhs: 9, rhs: 2, operator: .subtract, answer: 7)
        let mul = MathProblem(lhs: 5, rhs: 6, operator: .multiply, answer: 30)
        #expect(add.prompt == "3 + 4")
        #expect(sub.prompt == "9 - 2")
        #expect(mul.prompt == "5 × 6")
    }
}
