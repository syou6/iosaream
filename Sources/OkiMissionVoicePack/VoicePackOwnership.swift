import Foundation
import OkiMissionCore

public struct VoicePackOwnership: Hashable, Codable, Sendable {
    public let ownedPackIds: Set<UUID>
    public let subscriptionTier: SubscriptionTier

    public init(ownedPackIds: Set<UUID> = [], subscriptionTier: SubscriptionTier = .free) {
        self.ownedPackIds = ownedPackIds
        self.subscriptionTier = subscriptionTier
    }

    public func canPlay(_ pack: VoicePack) -> Bool {
        switch pack.tier {
        case .free: return true
        case .paidOneShot: return ownedPackIds.contains(pack.id)
        case .subscriberBundled: return subscriptionTier == .pro
        }
    }

    public func granting(packId: UUID) -> VoicePackOwnership {
        VoicePackOwnership(
            ownedPackIds: ownedPackIds.union([packId]),
            subscriptionTier: subscriptionTier
        )
    }

    public func revoking(packId: UUID) -> VoicePackOwnership {
        VoicePackOwnership(
            ownedPackIds: ownedPackIds.subtracting([packId]),
            subscriptionTier: subscriptionTier
        )
    }

    public func updatingSubscription(_ tier: SubscriptionTier) -> VoicePackOwnership {
        VoicePackOwnership(ownedPackIds: ownedPackIds, subscriptionTier: tier)
    }
}
