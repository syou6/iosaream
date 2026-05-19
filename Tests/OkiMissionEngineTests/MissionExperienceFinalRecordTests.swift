import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionEngine

private final class AdvanceableClock: AppClock, @unchecked Sendable {
    var current: TimeInterval = 0
    func now() -> Date { Date(timeIntervalSince1970: current) }
    func uptime() -> TimeInterval { current }
    func advance(_ seconds: TimeInterval) { current += seconds }
}

@Suite("MissionExperience.finalRecord")
struct MissionExperienceFinalRecordTests {
    private func mathTemplate() throws -> GeneratedMissionTemplate {
        let params = MathParams(problemCount: 2, operatorTypes: [.add], minOperand: 1, maxOperand: 5)
        return GeneratedMissionTemplate(
            id: UUID(uuidString: "55555555-0000-0000-0000-000000000001")!,
            kind: .math,
            difficulty: .easy,
            parametersJSON: try MissionParameterEncoder.encode(params),
            title: "math",
            estimatedDurationSeconds: 30,
            locale: "en-US",
            source: "test",
            contentHash: "h"
        )
    }

    @Test("successful run produces a success record with reps and duration")
    func successRecord() async throws {
        let clock = AdvanceableClock()
        let template = try mathTemplate()
        let runId = UUID(uuidString: "66666666-0000-0000-0000-000000000001")!
        let experience = try MissionExperience(
            template: template,
            configuration: .init(clock: clock),
            runId: runId
        )
        await experience.start()
        await experience.reportCapability(.notifications, authorized: true)
        for _ in 0..<8 {
            await experience.reportFraming(progress: 1.0)
        }
        clock.advance(15)
        let problems = await experience.problems
        _ = await experience.submitMathAnswer(problems[0].answer, at: 0)
        _ = await experience.submitMathAnswer(problems[1].answer, at: 1)

        let record = await experience.finalRecord(alarmId: UUID(uuidString: "77777777-0000-0000-0000-000000000001"))
        #expect(record.id == runId)
        #expect(record.templateId == template.id)
        #expect(record.outcome == .success)
        #expect(record.repsCompleted == 2)
        #expect(record.signals.isEmpty)
        #expect(record.antiCheatScore == 0)
        #expect(record.durationSeconds >= 15)
        #expect(record.completedAt != nil)
    }

    @Test("cancelled run produces a cancelled record")
    func cancelledRecord() async throws {
        let clock = AdvanceableClock()
        let experience = try MissionExperience(
            template: try mathTemplate(),
            configuration: .init(clock: clock)
        )
        await experience.start()
        clock.advance(5)
        await experience.cancel()
        let record = await experience.finalRecord()
        #expect(record.outcome == .cancelled)
        #expect(record.repsCompleted == 0)
    }

    @Test("cheated run carries signals and computed score")
    func cheatedRecord() async throws {
        let clock = AdvanceableClock()
        let policy = AntiCheatPolicy(failingScore: 4)
        let experience = try MissionExperience(
            template: try mathTemplate(),
            configuration: .init(antiCheatPolicy: policy, clock: clock)
        )
        await experience.start()
        await experience.reportCapability(.notifications, authorized: true)
        for _ in 0..<8 {
            await experience.reportFraming(progress: 1.0)
        }
        // No clock advance -> tooFast signal
        let problems = await experience.problems
        _ = await experience.submitMathAnswer(problems[0].answer, at: 0)
        _ = await experience.submitMathAnswer(problems[1].answer, at: 1)

        let record = await experience.finalRecord()
        #expect(record.outcome == .cheated)
        #expect(!record.signals.isEmpty)
        #expect(record.antiCheatScore >= 4)
    }

    @Test("failed run carries the failure reason")
    func failedRecord() async throws {
        let experience = try MissionExperience(template: try mathTemplate())
        await experience.start()
        await experience.reportCapability(.notifications, authorized: true)
        for _ in 0..<8 {
            await experience.reportFraming(progress: 1.0)
        }
        await experience.fail(.timeout)
        let record = await experience.finalRecord()
        #expect(record.outcome == .failure)
        #expect(record.failureReason == .timeout)
    }
}
