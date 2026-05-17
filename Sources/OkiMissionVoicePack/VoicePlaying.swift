import Foundation

public protocol VoicePlaying: Sendable {
    func play(_ clip: VoiceClip, from pack: VoicePack) async throws
    func stop() async
    func isPlaying() async -> Bool
}
