import Foundation

public struct VoicePackResolver: Sendable {
    private let rngSeed: UInt64

    public init(rngSeed: UInt64 = 0) {
        self.rngSeed = rngSeed
    }

    public func resolve(
        context: VoiceContext,
        from pack: VoicePack,
        ownership: VoicePackOwnership,
        pickIndex: Int = 0
    ) throws -> VoiceClip {
        guard ownership.canPlay(pack) else {
            throw VoicePackError.notEntitled(packId: pack.id)
        }
        let candidates = pack.clips(for: context)
        guard !candidates.isEmpty else {
            throw VoicePackError.clipNotFound(
                context: context,
                characterId: pack.characterId
            )
        }
        if context.allowsRandomPick {
            let safeIndex = abs(pickIndex) % candidates.count
            return candidates[safeIndex]
        }
        return candidates[0]
    }
}
