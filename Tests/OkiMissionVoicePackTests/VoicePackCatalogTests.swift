import Testing
import Foundation
@testable import OkiMissionVoicePack
import OkiMissionCore

@Suite("VoicePackCatalog")
struct VoicePackCatalogTests {
    private let free = VoicePack(
        id: UUID(),
        characterId: .defaultBuiltin,
        displayName: "Free",
        tier: .free,
        clips: []
    )
    private let paid = VoicePack(
        id: UUID(),
        characterId: CharacterId("oshi-a"),
        displayName: "Paid",
        iapProductId: "p1",
        tier: .paidOneShot,
        clips: []
    )

    @Test("pack(withId:) returns matching pack")
    func packById() {
        let catalog = VoicePackCatalog(packs: [free, paid])
        #expect(catalog.pack(withId: paid.id)?.id == paid.id)
        #expect(catalog.pack(withId: UUID()) == nil)
    }

    @Test("pack(forCharacter:) returns matching pack")
    func packByCharacter() {
        let catalog = VoicePackCatalog(packs: [free, paid])
        #expect(catalog.pack(forCharacter: CharacterId("oshi-a"))?.id == paid.id)
        #expect(catalog.pack(forCharacter: CharacterId("missing")) == nil)
    }

    @Test("playablePacks filters by ownership")
    func playableFilter() {
        let catalog = VoicePackCatalog(packs: [free, paid])
        let empty = VoicePackOwnership()
        #expect(catalog.playablePacks(under: empty).map(\.id) == [free.id])

        let owned = VoicePackOwnership(ownedPackIds: [paid.id])
        #expect(Set(catalog.playablePacks(under: owned).map(\.id)) == [free.id, paid.id])
    }
}
