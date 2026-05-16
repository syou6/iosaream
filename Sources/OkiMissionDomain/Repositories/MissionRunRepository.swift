import Foundation
import SwiftData
import OkiMissionCore

@ModelActor
public actor MissionRunRepository {
    public func record(_ entity: MissionRunEntity) throws {
        modelContext.insert(entity)
        try modelContext.save()
    }

    public func recent(limit: Int = 50) throws -> [MissionRunEntity] {
        var descriptor = FetchDescriptor<MissionRunEntity>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    public func successCount(since: Date) throws -> Int {
        let descriptor = FetchDescriptor<MissionRunEntity>(
            predicate: #Predicate { $0.startedAt >= since && $0.outcome == .success }
        )
        return try modelContext.fetchCount(descriptor)
    }

    public func recentKinds(limit: Int = 7) throws -> [MissionKind] {
        var descriptor = FetchDescriptor<MissionRunEntity>(
            predicate: #Predicate { $0.outcome == .success },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map(\.missionKind)
    }
}
