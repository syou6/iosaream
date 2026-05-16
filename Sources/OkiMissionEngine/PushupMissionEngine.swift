import Foundation
import OkiMissionCore

public final class PushupMissionEngine {
    public let targetReps: Int
    private let smoother: PoseSmoother
    private let counter: PushupRepCounter

    public init(
        targetReps: Int,
        smoother: PoseSmoother = PoseSmoother(),
        counter: PushupRepCounter = PushupRepCounter()
    ) {
        self.targetReps = max(1, targetReps)
        self.smoother = smoother
        self.counter = counter
    }

    @discardableResult
    public func consume(rawElbowAngle: Double, leftConfidence: Double, rightConfidence: Double) -> RepEvent? {
        let smoothed = smoother.smooth(rawElbowAngle)
        return counter.consume(
            elbowAngle: smoothed,
            leftConfidence: leftConfidence,
            rightConfidence: rightConfidence
        )
    }

    public var completedReps: Int { counter.repCount }
    public var isComplete: Bool { completedReps >= targetReps }
    public var progress: Double {
        Double(completedReps) / Double(targetReps)
    }

    public func reset() {
        smoother.reset()
        counter.reset()
    }
}
