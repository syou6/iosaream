import Foundation
import OkiMissionCore

public struct VoicePack: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let characterId: CharacterId
    public let displayName: String
    public let voiceActor: String?
    public let iapProductId: String?
    public let tier: VoicePackTier
    public let themeColorHex: String?
    public let clips: [VoiceClip]

    public init(
        id: UUID = UUID(),
        characterId: CharacterId,
        displayName: String,
        voiceActor: String? = nil,
        iapProductId: String? = nil,
        tier: VoicePackTier,
        themeColorHex: String? = nil,
        clips: [VoiceClip]
    ) {
        self.id = id
        self.characterId = characterId
        self.displayName = displayName
        self.voiceActor = voiceActor
        self.iapProductId = iapProductId
        self.tier = tier
        self.themeColorHex = themeColorHex
        self.clips = clips
    }
}

public extension VoicePack {
    var isFree: Bool { tier == .free }

    var requiresPurchase: Bool { tier == .paidOneShot && iapProductId != nil }

    var requiresSubscription: Bool { tier == .subscriberBundled }

    func clips(for context: VoiceContext) -> [VoiceClip] {
        clips.filter { $0.context == context }
    }
}
