import Foundation

public protocol VoiceAssetLocating: Sendable {
    func url(for assetName: String, characterId: CharacterId) throws -> URL
}
