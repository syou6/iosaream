import Foundation
import OkiMissionVoicePack

#if canImport(AVFoundation)
import AVFoundation

public actor AVFoundationVoicePlayer: VoicePlaying {
    private let locator: any VoiceAssetLocating
    private var currentPlayer: AVAudioPlayer?

    public init(locator: any VoiceAssetLocating) {
        self.locator = locator
    }

    public func play(_ clip: VoiceClip, from pack: VoicePack) async throws {
        let url: URL
        do {
            url = try locator.url(for: clip.assetName, characterId: pack.characterId)
        } catch let voiceError as VoicePackError {
            throw voiceError
        } catch {
            throw VoicePackError.assetMissing(name: clip.assetName)
        }

        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            throw VoicePackError.playbackFailed(reason: error.localizedDescription)
        }
        player.prepareToPlay()
        guard player.play() else {
            throw VoicePackError.playbackFailed(reason: "AVAudioPlayer.play() returned false")
        }
        currentPlayer?.stop()
        currentPlayer = player
    }

    public func stop() async {
        currentPlayer?.stop()
        currentPlayer = nil
    }

    public func isPlaying() async -> Bool {
        currentPlayer?.isPlaying ?? false
    }
}
#endif
