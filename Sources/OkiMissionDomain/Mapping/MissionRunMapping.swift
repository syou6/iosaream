import Foundation
import OkiMissionCore

public extension MissionRunRecord {
    init(entity: MissionRunEntity) {
        let signals: [AntiCheatSignal]
        if let json = entity.signalsJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([AntiCheatSignal].self, from: data) {
            signals = decoded
        } else {
            signals = []
        }
        let failure: MissionFailureReason?
        if let raw = entity.failureReasonRaw {
            failure = MissionFailureReason(rawValue: raw)
        } else {
            failure = nil
        }
        self.init(
            id: entity.id,
            alarmId: entity.alarmId,
            templateId: entity.templateId,
            missionKind: entity.missionKind,
            startedAt: entity.startedAt,
            completedAt: entity.completedAt,
            outcome: entity.outcome,
            failureReason: failure,
            durationSeconds: entity.durationSeconds,
            repsCompleted: entity.repsCompleted,
            antiCheatScore: entity.antiCheatScore,
            signals: signals,
            networkLatencyMs: entity.networkLatencyMs
        )
    }
}

public extension MissionRunEntity {
    static func make(from record: MissionRunRecord, now: Date = Date()) -> MissionRunEntity {
        let signalsJSON: String?
        if record.signals.isEmpty {
            signalsJSON = nil
        } else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            signalsJSON = (try? encoder.encode(record.signals)).map { String(decoding: $0, as: UTF8.self) }
        }
        return MissionRunEntity(
            id: record.id,
            alarmId: record.alarmId,
            templateId: record.templateId,
            missionKind: record.missionKind,
            startedAt: record.startedAt,
            completedAt: record.completedAt,
            outcome: record.outcome,
            failureReasonRaw: record.failureReason?.rawValue,
            durationSeconds: record.durationSeconds,
            repsCompleted: record.repsCompleted,
            antiCheatScore: record.antiCheatScore,
            signalsJSON: signalsJSON,
            networkLatencyMs: record.networkLatencyMs,
            createdAt: now,
            syncedAt: nil
        )
    }
}
