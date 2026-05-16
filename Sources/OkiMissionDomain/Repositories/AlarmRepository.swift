import Foundation
import SwiftData
import OkiMissionCore

@ModelActor
public actor AlarmRepository {
    public func allEnabled() throws -> [AlarmEntity] {
        let descriptor = FetchDescriptor<AlarmEntity>(
            predicate: #Predicate { $0.isEnabled == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func all() throws -> [AlarmEntity] {
        let descriptor = FetchDescriptor<AlarmEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func find(id: UUID) throws -> AlarmEntity? {
        let descriptor = FetchDescriptor<AlarmEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    public func upsert(spec: AlarmSpec, now: Date = Date()) throws -> AlarmEntity {
        if let existing = try find(id: spec.id) {
            existing.apply(spec: spec, now: now)
            try modelContext.save()
            return existing
        } else {
            let entity = AlarmEntity.make(from: spec, now: now)
            modelContext.insert(entity)
            try modelContext.save()
            return entity
        }
    }

    public func setAlarmKitId(domainId: UUID, kitId: UUID?) throws {
        guard let entity = try find(id: domainId) else { return }
        entity.alarmKitId = kitId
        entity.updatedAt = Date()
        try modelContext.save()
    }

    public func fetchAlarmKitId(domainId: UUID) throws -> UUID? {
        try find(id: domainId)?.alarmKitId
    }

    public func delete(id: UUID) throws {
        guard let entity = try find(id: id) else { return }
        modelContext.delete(entity)
        try modelContext.save()
    }

    public func setEnabled(id: UUID, enabled: Bool) throws {
        guard let entity = try find(id: id) else { return }
        entity.isEnabled = enabled
        entity.updatedAt = Date()
        try modelContext.save()
    }
}
