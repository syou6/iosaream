import Foundation

public actor InMemoryVoicePlayer: VoicePlaying {
    public private(set) var playLog: [PlayRecord] = []
    private var playing: Bool = false
    private var failNextWith: VoicePackError?

    public init() {}

    public struct PlayRecord: Equatable, Sendable {
        public let clipId: UUID
        public let packId: UUID
        public let assetName: String
        public let context: VoiceContext
    }

    public func setNextFailure(_ error: VoicePackError?) {
        failNextWith = error
    }

    public func play(_ clip: VoiceClip, from pack: VoicePack) async throws {
        if let error = failNextWith {
            failNextWith = nil
            throw error
        }
        playLog.append(
            PlayRecord(
                clipId: clip.id,
                packId: pack.id,
                assetName: clip.assetName,
                context: clip.context
            )
        )
        playing = true
    }

    public func stop() async {
        playing = false
    }

    public func isPlaying() async -> Bool {
        playing
    }

    public func reset() {
        playLog = []
        playing = false
        failNextWith = nil
    }
}
