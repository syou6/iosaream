import Testing
import Foundation
@testable import OkiMissionCore

@Suite("MissionParameters codec")
struct MissionParametersTests {
    @Test("PushupParams round-trips through JSON")
    func pushupRoundTrip() throws {
        let original = PushupParams(reps: 10, formStrictness: .strict, maxDurationSeconds: 90)
        let json = try MissionParameterEncoder.encode(original)
        let decoded = try MissionParameterDecoder.decode(json, as: PushupParams.self)
        #expect(decoded == original)
    }

    @Test("MathParams round-trips with operator list preserved")
    func mathRoundTrip() throws {
        let original = MathParams(
            problemCount: 5,
            operatorTypes: [.add, .subtract, .multiply],
            minOperand: 1,
            maxOperand: 20
        )
        let json = try MissionParameterEncoder.encode(original)
        let decoded = try MissionParameterDecoder.decode(json, as: MathParams.self)
        #expect(decoded == original)
        #expect(decoded.operatorTypes == [.add, .subtract, .multiply])
    }

    @Test("ObjectHuntParams preserves target classes")
    func objectHuntRoundTrip() throws {
        let original = ObjectHuntParams(
            targetClasses: ["remote_control", "book", "wallet"],
            requiredCount: 2
        )
        let json = try MissionParameterEncoder.encode(original)
        let decoded = try MissionParameterDecoder.decode(json, as: ObjectHuntParams.self)
        #expect(decoded == original)
    }

    @Test("encoded JSON is stable (sorted keys)")
    func stableKeys() throws {
        let params = PushupParams(reps: 5)
        let a = try MissionParameterEncoder.encode(params)
        let b = try MissionParameterEncoder.encode(params)
        #expect(a == b)
    }
}
