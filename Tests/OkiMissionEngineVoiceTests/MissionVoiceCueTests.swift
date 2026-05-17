import Testing
import Foundation
@testable import OkiMissionEngine
import OkiMissionCore
import OkiMissionVoicePack

@Suite("MissionVoiceCue")
struct MissionVoiceCueTests {
    private let pack: VoicePack = VoicePackSamples.samplePaidPack(
        characterId: CharacterId("oshi-a"),
        iapProductId: "com.example.oshia"
    )

    private func cue(player: InMemoryVoicePlayer, owned: Bool = true) -> MissionVoiceCue {
        let ownership: VoicePackOwnership = owned
            ? VoicePackOwnership(ownedPackIds: [pack.id])
            : VoicePackOwnership()
        return MissionVoiceCue(player: player, pack: pack, ownership: ownership)
    }

    @Test("fire plays expected clip for context")
    func firePlaysClip() async {
        let player = InMemoryVoicePlayer()
        await cue(player: player).fire(.missionStart)
        let log = await player.playLog
        #expect(log.count == 1)
        #expect(log[0].context == .missionStart)
    }

    @Test("fire swallows notEntitled silently")
    func fireSwallowsNotEntitled() async {
        let player = InMemoryVoicePlayer()
        await cue(player: player, owned: false).fire(.missionStart)
        let log = await player.playLog
        #expect(log.isEmpty)
    }

    @Test("fire swallows clipNotFound silently")
    func fireSwallowsClipNotFound() async {
        let player = InMemoryVoicePlayer()
        await cue(player: player).fire(.streakNewRecord)
        let log = await player.playLog
        #expect(log.isEmpty)
    }

    @Test("fire swallows player failure silently")
    func fireSwallowsPlayerFailure() async {
        let player = InMemoryVoicePlayer()
        await player.setNextFailure(.playbackFailed(reason: "test"))
        await cue(player: player).fire(.missionStart)
        let log = await player.playLog
        #expect(log.isEmpty)
    }
}
