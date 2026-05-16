import Foundation

public enum MissionOutcome: String, Codable, Sendable, CaseIterable {
    case success
    case failure
    case cancelled
    case cheated
}

public enum MissionFailureReason: String, Codable, Sendable {
    case timeout
    case userGaveUp
    case capabilityUnavailable
    case lowConfidence
    case interruptedTooLong
}

public enum AntiCheatSignal: Equatable, Sendable, Codable {
    case backgrounded(count: Int)
    case clockTampered(diffSeconds: Double)
    case screenshotsTaken(count: Int)
    case frameGaps(count: Int)
    case tooFast(durationSeconds: Double)
}

public enum AntiCheatVerdict: Equatable, Sendable {
    case clean
    case cheated([AntiCheatSignal])
}
