import Testing
import Foundation
@testable import OkiMissionVoicePack
import OkiMissionCore

@Suite("VoicePackResolver")
struct VoicePackResolverTests {
    private let pack: VoicePack = VoicePackSamples.samplePaidPack(
        characterId: CharacterId("oshi-a"),
        iapProductId: "com.example.oshia"
    )
    private let owned: VoicePackOwnership

    init() {
        self.owned = VoicePackOwnership(ownedPackIds: [pack.id])
    }

    @Test("returns alarm clip when entitled")
    func returnsAlarm() throws {
        let resolver = VoicePackResolver()
        let clip = try resolver.resolve(context: .alarmRinging, from: pack, ownership: owned)
        #expect(clip.context == .alarmRinging)
    }

    @Test("throws notEntitled when ownership missing")
    func throwsNotEntitled() {
        let resolver = VoicePackResolver()
        let empty = VoicePackOwnership()
        #expect(throws: VoicePackError.notEntitled(packId: pack.id)) {
            try resolver.resolve(context: .alarmRinging, from: pack, ownership: empty)
        }
    }

    @Test("throws clipNotFound when context absent")
    func throwsClipNotFound() {
        let resolver = VoicePackResolver()
        #expect(throws: VoicePackError.clipNotFound(context: .streakNewRecord, characterId: pack.characterId)) {
            try resolver.resolve(context: .streakNewRecord, from: pack, ownership: owned)
        }
    }

    @Test("pickIndex wraps via modulo for random-pick contexts")
    func pickIndexWraps() throws {
        let resolver = VoicePackResolver()
        let candidates = pack.clips(for: .missionEncouragement)
        #expect(candidates.count == 2)

        let zero = try resolver.resolve(context: .missionEncouragement, from: pack, ownership: owned, pickIndex: 0)
        let two = try resolver.resolve(context: .missionEncouragement, from: pack, ownership: owned, pickIndex: 2)
        #expect(zero.id == two.id)
    }

    @Test("alarmRinging ignores pickIndex (single canonical clip)")
    func alarmIgnoresPick() throws {
        let resolver = VoicePackResolver()
        let zero = try resolver.resolve(context: .alarmRinging, from: pack, ownership: owned, pickIndex: 0)
        let large = try resolver.resolve(context: .alarmRinging, from: pack, ownership: owned, pickIndex: 999)
        #expect(zero.id == large.id)
    }
}
