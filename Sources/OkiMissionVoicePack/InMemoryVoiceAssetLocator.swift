import Foundation

public struct InMemoryVoiceAssetLocator: VoiceAssetLocating {
    public let assets: [String: URL]

    public init(assets: [String: URL] = [:]) {
        self.assets = assets
    }

    public func url(for assetName: String, characterId: CharacterId) throws -> URL {
        let key = "\(characterId.rawValue)/\(assetName)"
        if let url = assets[key] { return url }
        if let url = assets[assetName] { return url }
        throw VoicePackError.assetMissing(name: assetName)
    }
}
