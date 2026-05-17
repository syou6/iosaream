import Foundation

public struct VoicePackManifest: Codable, Sendable {
    public let packs: [VoicePackEntry]

    public init(packs: [VoicePackEntry]) {
        self.packs = packs
    }

    public struct VoicePackEntry: Codable, Sendable {
        public let id: UUID
        public let characterId: String
        public let displayName: String
        public let voiceActor: String?
        public let iapProductId: String?
        public let tier: VoicePackTier
        public let themeColorHex: String?
        public let clips: [VoiceClipEntry]

        public init(
            id: UUID,
            characterId: String,
            displayName: String,
            voiceActor: String? = nil,
            iapProductId: String? = nil,
            tier: VoicePackTier,
            themeColorHex: String? = nil,
            clips: [VoiceClipEntry]
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

    public struct VoiceClipEntry: Codable, Sendable {
        public let id: UUID
        public let context: VoiceContext
        public let assetName: String
        public let transcript: String
        public let durationSeconds: Double

        public init(
            id: UUID,
            context: VoiceContext,
            assetName: String,
            transcript: String,
            durationSeconds: Double
        ) {
            self.id = id
            self.context = context
            self.assetName = assetName
            self.transcript = transcript
            self.durationSeconds = durationSeconds
        }
    }
}

public extension VoicePackManifest {
    func toCatalog() -> VoicePackCatalog {
        let packs = packs.map { entry in
            VoicePack(
                id: entry.id,
                characterId: CharacterId(entry.characterId),
                displayName: entry.displayName,
                voiceActor: entry.voiceActor,
                iapProductId: entry.iapProductId,
                tier: entry.tier,
                themeColorHex: entry.themeColorHex,
                clips: entry.clips.map { clip in
                    VoiceClip(
                        id: clip.id,
                        context: clip.context,
                        assetName: clip.assetName,
                        transcript: clip.transcript,
                        durationSeconds: clip.durationSeconds
                    )
                }
            )
        }
        return VoicePackCatalog(packs: packs)
    }
}
