import Foundation
import OkiMissionCore

public final class ObjectHuntMissionEngine {
    public let targetClasses: Set<String>
    public let requiredCount: Int
    public let confirmationFrames: Int

    private var foundClasses: Set<String> = []
    private var streaks: [String: Int] = [:]

    public init(targetClasses: [String], requiredCount: Int, confirmationFrames: Int = 3) {
        self.targetClasses = Set(targetClasses)
        self.requiredCount = max(1, requiredCount)
        self.confirmationFrames = max(1, confirmationFrames)
    }

    public func consume(detectedClasses: Set<String>) -> Set<String> {
        var newlyConfirmed: Set<String> = []
        for target in targetClasses {
            if detectedClasses.contains(target) {
                let next = (streaks[target] ?? 0) + 1
                streaks[target] = next
                if next >= confirmationFrames, !foundClasses.contains(target) {
                    foundClasses.insert(target)
                    newlyConfirmed.insert(target)
                }
            } else {
                streaks[target] = 0
            }
        }
        return newlyConfirmed
    }

    public var foundCount: Int { foundClasses.count }
    public var remainingCount: Int { max(0, requiredCount - foundCount) }
    public var isComplete: Bool { foundCount >= requiredCount }
    public var progress: Double {
        guard requiredCount > 0 else { return 1.0 }
        return min(1.0, Double(foundCount) / Double(requiredCount))
    }
    public var foundClassesSnapshot: [String] {
        foundClasses.sorted()
    }

    public func reset() {
        foundClasses.removeAll()
        streaks.removeAll()
    }
}
