import Foundation
import SwiftData
import OkiMissionCore

// Swift 6.x #Predicate macro does not support comparing enum case key paths
// (e.g. `$0.outcome == .success`). Predicates here filter what SwiftData can
// express, and the success check is applied in-memory after the fetch.

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
            predicate: #Predicate { $0.startedAt >= since }
        )
        return try modelContext.fetch(descriptor)
            .filter { $0.outcome == .success }
            .count
    }

    public func recentKinds(limit: Int = 7) throws -> [MissionKind] {
        var descriptor = FetchDescriptor<MissionRunEntity>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit * 4
        return try modelContext.fetch(descriptor)
            .filter { $0.outcome == .success }
            .prefix(limit)
            .map(\.missionKind)
    }

    public func unsynced(limit: Int = 50) throws -> [MissionRunEntity] {
        var descriptor = FetchDescriptor<MissionRunEntity>(
            predicate: #Predicate { $0.syncedAt == nil },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    public func markSynced(ids: [UUID], at date: Date = Date()) throws {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        let descriptor = FetchDescriptor<MissionRunEntity>(
            predicate: #Predicate { idSet.contains($0.id) }
        )
        for entity in try modelContext.fetch(descriptor) {
            entity.syncedAt = date
        }
        try modelContext.save()
    }
}
