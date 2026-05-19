import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionServices

private struct FailingGenerator: MissionGenerating {
    let error: any Error
    func generate(_ request: MissionGenerationRequest) async throws -> GeneratedMissionTemplate {
        throw error
    }
}

private struct ConstantGenerator: MissionGenerating {
    let template: GeneratedMissionTemplate
    func generate(_ request: MissionGenerationRequest) async throws -> GeneratedMissionTemplate {
        template
    }
}

private func sampleTemplate(source: String) -> GeneratedMissionTemplate {
    GeneratedMissionTemplate(
        kind: .math,
        difficulty: .easy,
        parametersJSON: "{}",
        title: "t",
        estimatedDurationSeconds: 30,
        locale: "en-US",
        source: source,
        contentHash: "h"
    )
}

@Suite("MissionGenerationOrchestrator")
struct MissionGenerationOrchestratorTests {
    @Test("primary success bypasses fallback")
    func primarySuccess() async throws {
        let primaryTemplate = sampleTemplate(source: "primary")
        let primary = ConstantGenerator(template: primaryTemplate)
        let fallback = ConstantGenerator(template: sampleTemplate(source: "fallback"))

        let trackerBox = TrackerBox()
        let orchestrator = MissionGenerationOrchestrator(primary: primary, fallback: fallback) { source in
            Task { await trackerBox.append(source) }
        }
        let result = try await orchestrator.generate(MissionGenerationRequest(
            targetDate: Date(),
            difficultyHint: .medium
        ))
        #expect(result.source == "primary")
        // give the Task a chance to run
        try await Task.sleep(nanoseconds: 50_000_000)
        let sources = await trackerBox.values
        #expect(sources == [.primary])
    }

    @Test("primary failure falls back to secondary")
    func fallbackInvoked() async throws {
        let primary = FailingGenerator(error: MissionGenerationError.providerUnavailable)
        let fallback = ConstantGenerator(template: sampleTemplate(source: "fallback"))

        let trackerBox = TrackerBox()
        let orchestrator = MissionGenerationOrchestrator(primary: primary, fallback: fallback) { source in
            Task { await trackerBox.append(source) }
        }
        let result = try await orchestrator.generate(MissionGenerationRequest(
            targetDate: Date(),
            difficultyHint: .easy
        ))
        #expect(result.source == "fallback")
        try await Task.sleep(nanoseconds: 50_000_000)
        let sources = await trackerBox.values
        #expect(sources == [.fallback])
    }

    @Test("both failing surfaces the fallback error")
    func bothFail() async {
        let primary = FailingGenerator(error: MissionGenerationError.providerUnavailable)
        let fallback = FailingGenerator(error: MissionGenerationError.rateLimited(remaining: 0))
        let orchestrator = MissionGenerationOrchestrator(primary: primary, fallback: fallback)
        await #expect(throws: MissionGenerationError.rateLimited(remaining: 0)) {
            _ = try await orchestrator.generate(MissionGenerationRequest(
                targetDate: Date(), difficultyHint: .easy
            ))
        }
    }
}

private actor TrackerBox {
    var values: [MissionGenerationOrchestrator.Source] = []
    func append(_ value: MissionGenerationOrchestrator.Source) {
        values.append(value)
    }
}
