import Foundation

public struct VoicePackCatalog: Hashable, Codable, Sendable {
    public let packs: [VoicePack]

    public init(packs: [VoicePack]) {
        self.packs = packs
    }

    public func pack(withId id: UUID) -> VoicePack? {
        packs.first { $0.id == id }
    }

    public func pack(forCharacter characterId: CharacterId) -> VoicePack? {
        packs.first { $0.characterId == characterId }
    }

    public func playablePacks(under ownership: VoicePackOwnership) -> [VoicePack] {
        packs.filter { ownership.canPlay($0) }
    }
}
