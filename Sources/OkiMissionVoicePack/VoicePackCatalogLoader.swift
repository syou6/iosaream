import Foundation

public enum VoicePackCatalogLoaderError: Error, Equatable, Sendable {
    case manifestNotFound(name: String)
    case decodingFailed(reason: String)
}

public enum VoicePackCatalogLoader {
    public static func load(
        manifestName: String = "voice-pack-manifest",
        from bundle: Bundle = .main
    ) throws -> VoicePackCatalog {
        guard let url = bundle.url(forResource: manifestName, withExtension: "json") else {
            throw VoicePackCatalogLoaderError.manifestNotFound(name: manifestName)
        }
        return try load(from: url)
    }

    public static func load(from url: URL) throws -> VoicePackCatalog {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw VoicePackCatalogLoaderError.decodingFailed(reason: "read failed: \(error.localizedDescription)")
        }
        return try load(jsonData: data)
    }

    public static func load(jsonData: Data) throws -> VoicePackCatalog {
        let decoder = JSONDecoder()
        do {
            let manifest = try decoder.decode(VoicePackManifest.self, from: jsonData)
            return manifest.toCatalog()
        } catch {
            throw VoicePackCatalogLoaderError.decodingFailed(reason: error.localizedDescription)
        }
    }
}
