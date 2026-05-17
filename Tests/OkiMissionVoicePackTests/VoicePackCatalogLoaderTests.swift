import Testing
import Foundation
@testable import OkiMissionVoicePack

@Suite("VoicePackCatalogLoader")
struct VoicePackCatalogLoaderTests {
    private let sampleJSON = """
    {
      "packs": [
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "characterId": "oshi-a",
          "displayName": "Oshi A",
          "voiceActor": "Talent A",
          "iapProductId": "com.example.oshia",
          "tier": "paidOneShot",
          "themeColorHex": "#FF6F91",
          "clips": [
            {
              "id": "22222222-2222-2222-2222-222222222222",
              "context": "alarmRinging",
              "assetName": "oshi-a_alarm.m4a",
              "transcript": "起きて",
              "durationSeconds": 3.5
            }
          ]
        }
      ]
    }
    """

    @Test
    func decodeRoundTrip() throws {
        let data = sampleJSON.data(using: .utf8)!
        let catalog = try VoicePackCatalogLoader.load(jsonData: data)
        #expect(catalog.packs.count == 1)
        let pack = catalog.packs[0]
        #expect(pack.characterId == CharacterId("oshi-a"))
        #expect(pack.displayName == "Oshi A")
        #expect(pack.voiceActor == "Talent A")
        #expect(pack.iapProductId == "com.example.oshia")
        #expect(pack.tier == .paidOneShot)
        #expect(pack.themeColorHex == "#FF6F91")
        #expect(pack.clips.count == 1)
        let clip = pack.clips[0]
        #expect(clip.context == .alarmRinging)
        #expect(clip.assetName == "oshi-a_alarm.m4a")
        #expect(clip.transcript == "起きて")
    }
}
