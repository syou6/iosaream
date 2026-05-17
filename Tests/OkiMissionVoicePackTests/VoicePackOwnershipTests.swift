import Testing
import Foundation
@testable import OkiMissionVoicePack
import OkiMissionCore

@Suite("VoicePackOwnership")
struct VoicePackOwnershipTests {
    private let freePack = VoicePack(
        characterId: .defaultBuiltin,
        displayName: "Free",
        tier: .free,
        clips: []
    )
    private let paidPack = VoicePack(
        id: UUID(),
        characterId: CharacterId("oshi-a"),
        displayName: "Paid",
        iapProductId: "com.example.oshia",
        tier: .paidOneShot,
        clips: []
    )
    private let subPack = VoicePack(
        id: UUID(),
        characterId: CharacterId("oshi-b"),
        displayName: "Sub",
        tier: .subscriberBundled,
        clips: []
    )

    @Test("free pack always playable")
    func freeAlwaysPlayable() {
        let ownership = VoicePackOwnership()
        #expect(ownership.canPlay(freePack) == true)
    }

    @Test("paid pack blocked until granted")
    func paidBlockedUntilGranted() {
        let ownership = VoicePackOwnership()
        #expect(ownership.canPlay(paidPack) == false)
        let after = ownership.granting(packId: paidPack.id)
        #expect(after.canPlay(paidPack) == true)
    }

    @Test("subscriber pack requires pro tier")
    func subscriberRequiresPro() {
        let free = VoicePackOwnership(subscriptionTier: .free)
        let pro = VoicePackOwnership(subscriptionTier: .pro)
        #expect(free.canPlay(subPack) == false)
        #expect(pro.canPlay(subPack) == true)
    }

    @Test("revoking removes ownership")
    func revoking() {
        let after = VoicePackOwnership(ownedPackIds: [paidPack.id])
            .revoking(packId: paidPack.id)
        #expect(after.canPlay(paidPack) == false)
    }

    @Test("updatingSubscription preserves owned ids")
    func updatingSubscriptionPreservesOwned() {
        let owned = VoicePackOwnership(ownedPackIds: [paidPack.id], subscriptionTier: .free)
        let upgraded = owned.updatingSubscription(.pro)
        #expect(upgraded.ownedPackIds == [paidPack.id])
        #expect(upgraded.subscriptionTier == .pro)
    }
}
