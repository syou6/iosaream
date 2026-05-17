import Foundation

public enum VoicePackError: Error, Equatable, Sendable {
    case packNotFound(id: UUID)
    case clipNotFound(context: VoiceContext, characterId: CharacterId)
    case notEntitled(packId: UUID)
    case assetMissing(name: String)
    case playbackFailed(reason: String)
}
