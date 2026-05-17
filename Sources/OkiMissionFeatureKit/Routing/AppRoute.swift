import Foundation
import OkiMissionCore

public enum AppRoute: Hashable, Sendable {
    case alarmDetail(alarmId: UUID)
    case alarmEditor(alarmId: UUID?)
    case missionRun(runId: UUID)
    case missionHistory
    case streakDetail
    case settings
    case subscription
    case profile
    case about
    case tokushoho
    case privacyPolicy
    case terms
}

public enum ModalRoute: Identifiable, Hashable, Sendable {
    case paywall
    case tokushohoSheet
    case onboarding
    case missionResult(MissionRunRecord)

    public var id: String {
        switch self {
        case .paywall: return "paywall"
        case .tokushohoSheet: return "tokushohoSheet"
        case .onboarding: return "onboarding"
        case .missionResult(let record): return "missionResult-\(record.id.uuidString)"
        }
    }
}

public enum FullScreenRoute: Identifiable, Hashable, Sendable {
    case missionRunner(templateId: UUID, alarmId: UUID?)
    case onboarding

    public var id: String {
        switch self {
        case .missionRunner(let templateId, _): return "missionRunner-\(templateId.uuidString)"
        case .onboarding: return "onboarding"
        }
    }
}
