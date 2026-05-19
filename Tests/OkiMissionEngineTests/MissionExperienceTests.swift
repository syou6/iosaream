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

@Suite("MissionExperience")
struct MissionExperienceTests {
    private func mathTemplate(count: Int = 2) throws -> GeneratedMissionTemplate {
        let params = MathParams(problemCount: count, operatorTypes: [.add], minOperand: 1, maxOperand: 5)
        return GeneratedMissionTemplate(
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

    private func shakeTemplate(required: Int = 2) throws -> GeneratedMissionTemplate {
        let params = ShakeParams(requiredShakes: required, minMagnitude: 1.5)
        return GeneratedMissionTemplate(
            kind: .shake,
            difficulty: .easy,
            parametersJSON: try MissionParameterEncoder.encode(params),
            title: "shake",
            estimatedDurationSeconds: 15,
            locale: "en-US",
            source: "test",
            contentHash: "h"
        )
    }

    private func barcodeTemplate(target: Int = 2) throws -> GeneratedMissionTemplate {
        let params = BarcodeParams(targetCount: target)
        return GeneratedMissionTemplate(
            kind: .barcode,
            difficulty: .easy,
            parametersJSON: try MissionParameterEncoder.encode(params),
            title: "barcode",
            estimatedDurationSeconds: 60,
            locale: "en-US",
            source: "test",
            contentHash: "h"
        )
    }

    @Test("math mission completes when all answers submitted correctly")
    func mathCompletes() async throws {
        let clock = AdvanceableClock()
        let template = try mathTemplate(count: 2)
        let experience = try MissionExperience(
            template: template,
            configuration: .init(clock: clock)
        )
        await experience.start()
        await experience.reportCapability(.notifications, authorized: true)
        await experience.reportFraming(progress: 1.0)
        for _ in 0..<8 {
            await experience.reportFraming(progress: 1.0)
        }

        let problems = await experience.problems
        #expect(problems.count == 2)

        clock.advance(15)
        _ = await experience.submitMathAnswer(problems[0].answer, at: 0)
        _ = await experience.submitMathAnswer(problems[1].answer, at: 1)

        let finalState = await experience.currentState
        #expect(finalState == .completed)
    }

    @Test("math mission submitted in under minimum duration flags as cheated")
    func mathCheatedWhenTooFast() async throws {
        let clock = AdvanceableClock()
        let template = try mathTemplate(count: 2)
        // Lower failingScore so a single tooFast signal (4 points) trips the verdict.
        let policy = AntiCheatPolicy(failingScore: 4)
        let experience = try MissionExperience(
            template: template,
            configuration: .init(antiCheatPolicy: policy, clock: clock)
        )
        await experience.start()
        await experience.reportCapability(.notifications, authorized: true)
        for _ in 0..<8 {
            await experience.reportFraming(progress: 1.0)
        }
        let problems = await experience.problems

        // No clock advance -> 0 duration -> well under math minimum of 8s
        _ = await experience.submitMathAnswer(problems[0].answer, at: 0)
        _ = await experience.submitMathAnswer(problems[1].answer, at: 1)

        let state = await experience.currentState
        switch state {
        case .cheated(let signals):
            #expect(signals.contains { signal in
                if case .tooFast = signal { return true }
                return false
            })
        default:
            Issue.record("expected cheated, got \(state)")
        }
    }

    @Test("shake mission completes after required shakes")
    func shakeCompletes() async throws {
        let clock = AdvanceableClock()
        let template = try shakeTemplate(required: 2)
        let experience = try MissionExperience(
            template: template,
            configuration: .init(clock: clock)
        )
        await experience.start()
        await experience.reportCapability(.motion, authorized: true)
        for _ in 0..<8 {
            await experience.reportFraming(progress: 1.0)
        }
        clock.advance(10)
        await experience.reportMotionSample(AccelerationSample(x: 2, y: 0, z: 0, timestamp: 1.0))
        await experience.reportMotionSample(AccelerationSample(x: 2, y: 0, z: 0, timestamp: 2.0))

        let state = await experience.currentState
        #expect(state == .completed)
    }

    @Test("barcode mission deduplicates payloads")
    func barcodeDedupe() async throws {
        let clock = AdvanceableClock()
        let template = try barcodeTemplate(target: 2)
        let experience = try MissionExperience(
            template: template,
            configuration: .init(clock: clock)
        )
        await experience.start()
        await experience.reportCapability(.camera, authorized: true)
        for _ in 0..<8 {
            await experience.reportFraming(progress: 1.0)
        }
        clock.advance(10)
        await experience.reportBarcode("AAA")
        await experience.reportBarcode("AAA")
        let midState = await experience.currentState
        if case .running = midState {} else {
            Issue.record("expected running after duplicate barcode, got \(midState)")
        }
        await experience.reportBarcode("BBB")
        let final = await experience.currentState
        #expect(final == .completed)
    }

    @Test("cancel terminates the experience")
    func cancelTerminates() async throws {
        let template = try mathTemplate()
        let experience = try MissionExperience(template: template)
        await experience.start()
        await experience.cancel()
        let state = await experience.currentState
        #expect(state == .cancelled)
    }

    @Test("recordBackgrounded contributes to cheat verdict")
    func backgroundedSignal() async throws {
        let clock = AdvanceableClock()
        let template = try mathTemplate(count: 2)
        let experience = try MissionExperience(
            template: template,
            configuration: .init(clock: clock)
        )
        await experience.start()
        await experience.reportCapability(.notifications, authorized: true)
        for _ in 0..<8 {
            await experience.reportFraming(progress: 1.0)
        }
        await experience.recordBackgrounded()
        await experience.recordBackgrounded()
        await experience.recordBackgrounded()
        await experience.resume()
        clock.advance(15)
        let problems = await experience.problems
        _ = await experience.submitMathAnswer(problems[0].answer, at: 0)
        _ = await experience.submitMathAnswer(problems[1].answer, at: 1)
        let state = await experience.currentState
        switch state {
        case .cheated(let signals):
            #expect(signals.contains { signal in
                if case .backgrounded(let count) = signal { return count == 3 }
                return false
            })
        default:
            Issue.record("expected cheated due to backgrounding, got \(state)")
        }
    }
}
