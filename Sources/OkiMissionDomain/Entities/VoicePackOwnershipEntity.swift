import Foundation
import SwiftData

@Model
public final class VoicePackOwnershipEntity {
    @Attribute(.unique) public var packId: UUID
    public var characterIdRaw: String
    public var iapProductId: String?
    public var purchasedAt: Date
    public var revokedAt: Date?

    public init(
        packId: UUID,
        characterIdRaw: String,
        iapProductId: String? = nil,
        purchasedAt: Date = Date(),
        revokedAt: Date? = nil
    ) {
        self.packId = packId
        self.characterIdRaw = characterIdRaw
        self.iapProductId = iapProductId
        self.purchasedAt = purchasedAt
        self.revokedAt = revokedAt
    }

    public var isActive: Bool { revokedAt == nil }
}
