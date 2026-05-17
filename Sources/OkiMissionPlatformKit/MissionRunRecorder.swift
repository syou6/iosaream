import Foundation
import OkiMissionCore
import OkiMissionServices

// Records a completed mission to the local persistence layer and pushes
// it through the sync pipeline. The App layer wires the closures to
// MissionRunRepository methods so this actor stays free of any direct
// SwiftData dependency.

public actor MissionRunRecorder {
    public typealias Persist = @Sendable (MissionRunRecord) async throws -> Void
    public typealias Track = @Sendable (AnalyticsEvent) async -> Void
    public typealias TriggerSync = @Sendable () async -> Void

    private let persist: Persist
    private let track: Track?
    private let triggerSync: TriggerSync?

    public init(
        persist: @escaping Persist,
        track: Track? = nil,
        triggerSync: TriggerSync? = nil
    ) {
        self.persist = persist
        self.track = track
        self.triggerSync = triggerSync
    }

    public func record(_ record: MissionRunRecord) async throws {
        try await persist(record)
        if let track {
            let name: String
            switch record.outcome {
            case .success: name = AnalyticsEventName.missionCompleted
            case .failure: name = AnalyticsEventName.missionFailed
            case .cancelled: name = "mission_cancelled"
            case .cheated: name = AnalyticsEventName.missionCheated
            }
            let event = AnalyticsEvent(
                name: name,
                properties: [
                    "mission_kind": .string(record.missionKind.rawValue),
                    "reps_completed": .int(record.repsCompleted),
                    "duration_seconds": .double(record.durationSeconds),
                    "anti_cheat_score": .int(record.antiCheatScore),
                ]
            )
            await track(event)
        }
        await triggerSync?()
    }
}
