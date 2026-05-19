import Testing
import Foundation
@testable import OkiMissionVoicePack

@Suite("InMemoryVoicePlayer")
struct InMemoryVoicePlayerTests {
    private let pack = VoicePackSamples.defaultPack()

    @Test("records play call in log")
    func recordsPlay() async throws {
        let player = InMemoryVoicePlayer()
        let clip = pack.clips(for: .missionStart).first!
        try await player.play(clip, from: pack)
        let log = await player.playLog
        #expect(log.count == 1)
        #expect(log[0].clipId == clip.id)
        #expect(log[0].context == .missionStart)
        #expect(await player.isPlaying() == true)
    }

    @Test("stop sets isPlaying false")
    func stop() async throws {
        let player = InMemoryVoicePlayer()
        let clip = pack.clips(for: .missionStart).first!
        try await player.play(clip, from: pack)
        await player.stop()
        #expect(await player.isPlaying() == false)
    }

    @Test("setNextFailure injects error once")
    func injectFailure() async throws {
        let player = InMemoryVoicePlayer()
        await player.setNextFailure(.playbackFailed(reason: "test"))
        let clip = pack.clips(for: .missionStart).first!

        await #expect(throws: VoicePackError.playbackFailed(reason: "test")) {
            try await player.play(clip, from: pack)
        }

        try await player.play(clip, from: pack)
        let log = await player.playLog
        #expect(log.count == 1)
    }

    @Test("reset clears log and state")
    func reset() async throws {
        let player = InMemoryVoicePlayer()
        let clip = pack.clips(for: .missionStart).first!
        try await player.play(clip, from: pack)
        await player.reset()
        #expect(await player.playLog.isEmpty)
        #expect(await player.isPlaying() == false)
    }
}
