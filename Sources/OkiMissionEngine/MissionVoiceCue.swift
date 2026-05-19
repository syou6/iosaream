import Foundation
import OkiMissionCore
import OkiMissionVoicePack

public struct MissionVoiceCue: Sendable {
    public let player: any VoicePlaying
    public let pack: VoicePack
    public let ownership: VoicePackOwnership
    public let resolver: VoicePackResolver

    public init(
        player: any VoicePlaying,
        pack: VoicePack,
        ownership: VoicePackOwnership,
        resolver: VoicePackResolver = VoicePackResolver()
    ) {
        self.player = player
        self.pack = pack
        self.ownership = ownership
        self.resolver = resolver
    }

    public func fire(_ context: VoiceContext, pickIndex: Int = 0) async {
        do {
            let clip = try resolver.resolve(
                context: context,
                from: pack,
                ownership: ownership,
                pickIndex: pickIndex
            )
            try await player.play(clip, from: pack)
        } catch {
            return
        }
    }
}
