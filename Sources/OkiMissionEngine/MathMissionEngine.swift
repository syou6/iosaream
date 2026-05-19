import Foundation
import OkiMissionCore

public final class MathMissionEngine {
    public let problems: [MathProblem]
    public private(set) var answers: [Int?]
    public private(set) var correctCount: Int = 0

    public init(problems: [MathProblem]) {
        self.problems = problems
        self.answers = Array(repeating: nil, count: problems.count)
    }

    @discardableResult
    public func submit(answer: Int, at index: Int) -> Bool {
        guard problems.indices.contains(index), answers[index] == nil else {
            return false
        }
        answers[index] = answer
        if answer == problems[index].answer {
            correctCount += 1
            return true
        }
        return false
    }

    public var answeredCount: Int {
        answers.lazy.filter { $0 != nil }.count
    }

    public var isComplete: Bool {
        answeredCount == problems.count
    }

    public var isPerfect: Bool {
        isComplete && correctCount == problems.count
    }

    public var progress: Double {
        guard !problems.isEmpty else { return 1.0 }
        return Double(answeredCount) / Double(problems.count)
    }
}
