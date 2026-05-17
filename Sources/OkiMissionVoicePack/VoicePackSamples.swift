import Foundation

public enum VoicePackSamples {
    public static func defaultPack() -> VoicePack {
        VoicePack(
            characterId: .defaultBuiltin,
            displayName: "Default",
            voiceActor: nil,
            iapProductId: nil,
            tier: .free,
            themeColorHex: "#8E8E93",
            clips: [
                VoiceClip(
                    context: .alarmRinging,
                    assetName: "default_alarm.m4a",
                    transcript: "(beep)",
                    durationSeconds: 30.0
                ),
                VoiceClip(
                    context: .missionStart,
                    assetName: "default_start.m4a",
                    transcript: "始めましょう",
                    durationSeconds: 1.2
                ),
                VoiceClip(
                    context: .missionSuccess,
                    assetName: "default_success.m4a",
                    transcript: "クリア",
                    durationSeconds: 1.0
                )
            ]
        )
    }

    public static func samplePaidPack(characterId: CharacterId, iapProductId: String) -> VoicePack {
        VoicePack(
            characterId: characterId,
            displayName: "Sample Oshi Pack",
            voiceActor: "Sample Talent",
            iapProductId: iapProductId,
            tier: .paidOneShot,
            themeColorHex: "#FF6F91",
            clips: [
                VoiceClip(
                    context: .alarmRinging,
                    assetName: "\(characterId.rawValue)_alarm.m4a",
                    transcript: "起きて、もう朝だよ",
                    durationSeconds: 4.0
                ),
                VoiceClip(
                    context: .missionStart,
                    assetName: "\(characterId.rawValue)_start_1.m4a",
                    transcript: "ミッション始まるよ、ファイト",
                    durationSeconds: 2.4
                ),
                VoiceClip(
                    context: .missionEncouragement,
                    assetName: "\(characterId.rawValue)_cheer_1.m4a",
                    transcript: "もう少し、頑張って",
                    durationSeconds: 1.8
                ),
                VoiceClip(
                    context: .missionEncouragement,
                    assetName: "\(characterId.rawValue)_cheer_2.m4a",
                    transcript: "えらい、その調子",
                    durationSeconds: 1.6
                ),
                VoiceClip(
                    context: .missionSuccess,
                    assetName: "\(characterId.rawValue)_success.m4a",
                    transcript: "やった、おはよう",
                    durationSeconds: 2.2
                ),
                VoiceClip(
                    context: .missionFailure,
                    assetName: "\(characterId.rawValue)_fail.m4a",
                    transcript: "また明日チャレンジしよう",
                    durationSeconds: 2.0
                )
            ]
        )
    }
}
