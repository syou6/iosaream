import Testing
import Foundation
@testable import OkiMissionVoicePack

@Suite("InMemoryVoiceAssetLocator")
struct InMemoryVoiceAssetLocatorTests {
    @Test("resolves namespaced key first")
    func namespacedKey() throws {
        let url = URL(fileURLWithPath: "/tmp/oshi-a/sample.m4a")
        let locator = InMemoryVoiceAssetLocator(assets: ["oshi-a/sample.m4a": url])
        let resolved = try locator.url(for: "sample.m4a", characterId: CharacterId("oshi-a"))
        #expect(resolved == url)
    }

    @Test("falls back to bare key")
    func bareKey() throws {
        let url = URL(fileURLWithPath: "/tmp/sample.m4a")
        let locator = InMemoryVoiceAssetLocator(assets: ["sample.m4a": url])
        let resolved = try locator.url(for: "sample.m4a", characterId: CharacterId("any"))
        #expect(resolved == url)
    }

    @Test("throws assetMissing when neither key present")
    func missing() {
        let locator = InMemoryVoiceAssetLocator()
        #expect(throws: VoicePackError.assetMissing(name: "x.m4a")) {
            try locator.url(for: "x.m4a", characterId: CharacterId("z"))
        }
    }
}
