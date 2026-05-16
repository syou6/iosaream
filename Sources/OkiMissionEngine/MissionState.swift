import Foundation
import OkiMissionCore

public enum PauseReason: String, Sendable, Equatable, Codable {
    case appBackgrounded
    case audioInterrupted
    case lowConfidence
    case userInitiated
}

public enum MissionState: Sendable, Equatable {
    case idle
    case checkingCapabilities
    case awaitingPermission(Capability)
    case framing(progress: Double)
    case running(progress: Double)
    case paused(PauseReason)
    case verifying
    case completed
    case failed(MissionFailureReason)
    case cancelled
    case cheated([AntiCheatSignal])
}

public extension MissionState {
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .cheated:
            return true
        default:
            return false
        }
    }

    var isActive: Bool {
        switch self {
        case .framing, .running, .paused, .verifying:
            return true
        default:
            return false
        }
    }
}

public enum MissionEvent: Sendable, Equatable {
    case stateChanged(MissionState)
    case progressUpdated(Double)
    case repCompleted(count: Int)
    case warning(String)
}
