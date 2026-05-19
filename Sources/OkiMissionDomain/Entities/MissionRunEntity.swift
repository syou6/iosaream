import Foundation
import SwiftData
import OkiMissionCore

@Model
public final class MissionRunEntity {
    @Attribute(.unique) public var id: UUID
    public var alarmId: UUID?
    public var templateId: UUID?
    public var missionKind: MissionKind
    public var startedAt: Date
    public var completedAt: Date?
    public var outcome: MissionOutcome
    public var failureReasonRaw: String?
    public var durationSeconds: Double
    public var repsCompleted: Int
    public var antiCheatScore: Int
    public var signalsJSON: String?
    public var networkLatencyMs: Int?
    public var createdAt: Date
    public var syncedAt: Date?

    public init(
        id: UUID = UUID(),
        alarmId: UUID? = nil,
        templateId: UUID? = nil,
        missionKind: MissionKind,
        startedAt: Date,
        completedAt: Date? = nil,
        outcome: MissionOutcome,
        failureReasonRaw: String? = nil,
        durationSeconds: Double,
        repsCompleted: Int = 0,
        antiCheatScore: Int = 0,
        signalsJSON: String? = nil,
        networkLatencyMs: Int? = nil,
        createdAt: Date = Date(),
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.alarmId = alarmId
        self.templateId = templateId
        self.missionKind = missionKind
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.outcome = outcome
        self.failureReasonRaw = failureReasonRaw
        self.durationSeconds = durationSeconds
        self.repsCompleted = repsCompleted
        self.antiCheatScore = antiCheatScore
        self.signalsJSON = signalsJSON
        self.networkLatencyMs = networkLatencyMs
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}
