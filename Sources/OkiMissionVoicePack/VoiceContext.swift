import Foundation
import OkiMissionCore

public enum VoiceContext: String, Codable, Sendable, CaseIterable, Hashable {
    case alarmRinging
    case missionStart
    case missionEncouragement
    case missionSuccess
    case missionFailure
    case missionRetry
    case streakNewRecord
    case streakDailyGreeting
}

public extension VoiceContext {
    static func encouragement(for kind: MissionKind) -> VoiceContext {
        .missionEncouragement
    }

    var allowsRandomPick: Bool {
        switch self {
        case .alarmRinging: return false
        default: return true
        }
    }
}
