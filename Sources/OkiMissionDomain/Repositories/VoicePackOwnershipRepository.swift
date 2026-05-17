import Foundation
import SwiftData

@ModelActor
public actor VoicePackOwnershipRepository {
    public func grant(packId: UUID, characterIdRaw: String, iapProductId: String?, at date: Date = Date()) throws {
        if let existing = try fetchEntity(packId: packId) {
            existing.revokedAt = nil
            existing.purchasedAt = date
            existing.iapProductId = iapProductId
        } else {
            modelContext.insert(
                VoicePackOwnershipEntity(
                    packId: packId,
                    characterIdRaw: characterIdRaw,
                    iapProductId: iapProductId,
                    purchasedAt: date
                )
            )
        }
        try modelContext.save()
    }

    public func revoke(packId: UUID, at date: Date = Date()) throws {
        guard let existing = try fetchEntity(packId: packId) else { return }
        existing.revokedAt = date
        try modelContext.save()
    }

    public func activeOwnedPackIds() throws -> Set<UUID> {
        let descriptor = FetchDescriptor<VoicePackOwnershipEntity>(
            predicate: #Predicate { $0.revokedAt == nil }
        )
        return Set(try modelContext.fetch(descriptor).map(\.packId))
    }

    public func all() throws -> [VoicePackOwnershipEntity] {
        try modelContext.fetch(FetchDescriptor<VoicePackOwnershipEntity>())
    }

    private func fetchEntity(packId: UUID) throws -> VoicePackOwnershipEntity? {
        let descriptor = FetchDescriptor<VoicePackOwnershipEntity>(
            predicate: #Predicate { $0.packId == packId }
        )
        return try modelContext.fetch(descriptor).first
    }
}
