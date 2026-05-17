import Foundation
import OkiMissionVoicePack

public struct BundleVoiceAssetLocator: VoiceAssetLocating {
    private let bundle: Bundle
    private let subdirectory: String?

    public init(bundle: Bundle = .main, subdirectory: String? = "Voices") {
        self.bundle = bundle
        self.subdirectory = subdirectory
    }

    public func url(for assetName: String, characterId: CharacterId) throws -> URL {
        let (base, ext) = splitExtension(assetName)
        let candidateSubdirs: [String?] = [
            subdirectory.map { "\($0)/\(characterId.rawValue)" },
            subdirectory,
            characterId.rawValue,
            nil
        ]
        for candidate in candidateSubdirs {
            if let url = bundle.url(forResource: base, withExtension: ext, subdirectory: candidate) {
                return url
            }
        }
        throw VoicePackError.assetMissing(name: assetName)
    }

    private func splitExtension(_ name: String) -> (String, String?) {
        guard let dot = name.lastIndex(of: ".") else { return (name, nil) }
        let base = String(name[..<dot])
        let ext = String(name[name.index(after: dot)...])
        return (base, ext.isEmpty ? nil : ext)
    }
}
