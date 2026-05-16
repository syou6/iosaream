import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionServices

@Suite("StubMissionGenerator")
struct StubMissionGeneratorTests {
    @Test("avoids recent kinds when possible")
    func avoidsRecent() async throws {
        let generator = StubMissionGenerator()
        let request = MissionGenerationRequest(
            targetDate: Date(),
            difficultyHint: .medium,
            recentKinds: [.math, .pushup],
            preferredKinds: [.math, .pushup, .shake]
        )
        for _ in 0..<10 {
            let template = try await generator.generate(request)
            #expect(template.kind == .shake)
        }
    }

    @Test("falls back to full pool when all kinds recent")
    func fallsBackWhenAllRecent() async throws {
        let generator = StubMissionGenerator()
        let request = MissionGenerationRequest(
            targetDate: Date(),
            difficultyHint: .easy,
            recentKinds: MissionKind.allCases,
            preferredKinds: MissionKind.allCases
        )
        let template = try await generator.generate(request)
        #expect(MissionKind.allCases.contains(template.kind))
    }

    @Test("respects disabled kinds")
    func respectsDisabled() async throws {
        let generator = StubMissionGenerator()
        let request = MissionGenerationRequest(
            targetDate: Date(),
            difficultyHint: .easy,
            disabledKinds: [.pushup, .squat, .objectHunt, .barcode, .shake]
        )
        for _ in 0..<10 {
            let template = try await generator.generate(request)
            #expect(template.kind == .math)
        }
    }

    @Test("difficulty scales reps for pushup")
    func difficultyScales() async throws {
        let generator = StubMissionGenerator()
        let easy = try await generator.generate(MissionGenerationRequest(
            targetDate: Date(), difficultyHint: .easy, preferredKinds: [.pushup]
        ))
        let hard = try await generator.generate(MissionGenerationRequest(
            targetDate: Date(), difficultyHint: .hard, preferredKinds: [.pushup]
        ))
        let easyParams = try MissionParameterDecoder.decode(easy.parametersJSON, as: PushupParams.self)
        let hardParams = try MissionParameterDecoder.decode(hard.parametersJSON, as: PushupParams.self)
        #expect(hardParams.reps > easyParams.reps)
    }

    @Test("japanese locale produces japanese title")
    func japaneseTitle() async throws {
        let generator = StubMissionGenerator()
        let template = try await generator.generate(MissionGenerationRequest(
            targetDate: Date(),
            difficultyHint: .easy,
            locale: "ja-JP",
            preferredKinds: [.math]
        ))
        #expect(template.title.contains("計算"))
    }

    @Test("english locale produces english title")
    func englishTitle() async throws {
        let generator = StubMissionGenerator()
        let template = try await generator.generate(MissionGenerationRequest(
            targetDate: Date(),
            difficultyHint: .easy,
            locale: "en-US",
            preferredKinds: [.pushup]
        ))
        #expect(template.title.lowercased().contains("pushup"))
    }
}
