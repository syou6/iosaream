import Foundation
import OkiMissionCore

public struct MathProblem: Sendable, Equatable {
    public let lhs: Int
    public let rhs: Int
    public let `operator`: MathOperator
    public let answer: Int

    public var prompt: String {
        let symbol: String
        switch `operator` {
        case .add: symbol = "+"
        case .subtract: symbol = "-"
        case .multiply: symbol = "×"
        }
        return "\(lhs) \(symbol) \(rhs)"
    }
}

public struct MathProblemGenerator: Sendable {
    public let params: MathParams

    public init(params: MathParams) {
        self.params = params
    }

    public func generate<G: RandomNumberGenerator>(using generator: inout G) -> [MathProblem] {
        guard !params.operatorTypes.isEmpty, params.problemCount > 0 else { return [] }
        var problems: [MathProblem] = []
        problems.reserveCapacity(params.problemCount)
        for _ in 0..<params.problemCount {
            problems.append(generateOne(using: &generator))
        }
        return problems
    }

    public func generate() -> [MathProblem] {
        var generator = SystemRandomNumberGenerator()
        return generate(using: &generator)
    }

    private func generateOne<G: RandomNumberGenerator>(using generator: inout G) -> MathProblem {
        let op = params.operatorTypes.randomElement(using: &generator) ?? .add
        let range = params.minOperand...max(params.minOperand, params.maxOperand)
        let a = Int.random(in: range, using: &generator)
        let b = Int.random(in: range, using: &generator)
        switch op {
        case .add:
            return MathProblem(lhs: a, rhs: b, operator: .add, answer: a + b)
        case .subtract:
            let (larger, smaller) = a >= b ? (a, b) : (b, a)
            return MathProblem(lhs: larger, rhs: smaller, operator: .subtract, answer: larger - smaller)
        case .multiply:
            return MathProblem(lhs: a, rhs: b, operator: .multiply, answer: a * b)
        }
    }
}

public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEAD_BEEF : seed
    }

    public mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
