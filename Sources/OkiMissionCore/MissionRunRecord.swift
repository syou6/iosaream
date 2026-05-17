import Foundation

public struct MissionRunRecord: Hashable, Sendable, Codable, Identifiable {
    public let id: UUID
    public var alarmId: UUID?
    public var templateId: UUID?
    public var missionKind: MissionKind
    public var startedAt: Date
    public var completedAt: Date?
    public var outcome: MissionOutcome
    public var failureReason: MissionFailureReason?
    public var durationSeconds: Double
    public var repsCompleted: Int
    public var antiCheatScore: Int
    public var signals: [AntiCheatSignal]
    public var networkLatencyMs: Int?

    public init(
        id: UUID = UUID(),
        alarmId: UUID? = nil,
        templateId: UUID? = nil,
        missionKind: MissionKind,
        startedAt: Date,
        completedAt: Date? = nil,
        outcome: MissionOutcome,
        failureReason: MissionFailureReason? = nil,
        durationSeconds: Double,
        repsCompleted: Int = 0,
        antiCheatScore: Int = 0,
        signals: [AntiCheatSignal] = [],
        networkLatencyMs: Int? = nil
    ) {
        self.id = id
        self.alarmId = alarmId
        self.templateId = templateId
        self.missionKind = missionKind
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.outcome = outcome
        self.failureReason = failureReason
        self.durationSeconds = durationSeconds
        self.repsCompleted = repsCompleted
        self.antiCheatScore = antiCheatScore
        self.signals = signals
        self.networkLatencyMs = networkLatencyMs
    }
}
