import Foundation
import OkiMissionCore

public enum SampleTemplates {
    public static func pushup(reps: Int = 10, difficulty: Difficulty = .medium) -> GeneratedMissionTemplate {
        let params = PushupParams(reps: reps)
        let json = (try? MissionParameterEncoder.encode(params)) ?? "{}"
        return GeneratedMissionTemplate(
            id: UUID(uuidString: "33333333-0000-0000-0000-000000000001")!,
            kind: .pushup,
            difficulty: difficulty,
            parametersJSON: json,
            title: "\(reps)回の腕立て伏せ",
            subtitle: "朝の体を起こそう",
            encouragement: "がんばろう！",
            estimatedDurationSeconds: TimeInterval(reps * 6),
            locale: "ja-JP",
            source: "sample",
            generatedAt: Date(timeIntervalSinceReferenceDate: 0),
            contentHash: "sample-pushup-\(reps)"
        )
    }

    public static func math(count: Int = 3, difficulty: Difficulty = .easy) -> GeneratedMissionTemplate {
        let params = MathParams(
            problemCount: count,
            operatorTypes: [.add, .subtract],
            minOperand: 1,
            maxOperand: 12
        )
        let json = (try? MissionParameterEncoder.encode(params)) ?? "{}"
        return GeneratedMissionTemplate(
            id: UUID(uuidString: "33333333-0000-0000-0000-000000000002")!,
            kind: .math,
            difficulty: difficulty,
            parametersJSON: json,
            title: "計算 \(count) 問",
            subtitle: "頭を起こそう",
            estimatedDurationSeconds: TimeInterval(count * 10),
            locale: "ja-JP",
            source: "sample",
            generatedAt: Date(timeIntervalSinceReferenceDate: 0),
            contentHash: "sample-math-\(count)"
        )
    }

    public static func shake(shakes: Int = 15, difficulty: Difficulty = .easy) -> GeneratedMissionTemplate {
        let params = ShakeParams(requiredShakes: shakes)
        let json = (try? MissionParameterEncoder.encode(params)) ?? "{}"
        return GeneratedMissionTemplate(
            id: UUID(uuidString: "33333333-0000-0000-0000-000000000003")!,
            kind: .shake,
            difficulty: difficulty,
            parametersJSON: json,
            title: "\(shakes) 回シェイク",
            subtitle: "目を覚まそう",
            estimatedDurationSeconds: TimeInterval(shakes),
            locale: "ja-JP",
            source: "sample",
            generatedAt: Date(timeIntervalSinceReferenceDate: 0),
            contentHash: "sample-shake-\(shakes)"
        )
    }

    public static func objectHunt(
        targets: [String] = ["remote_control", "book", "wallet"],
        required: Int = 2
    ) -> GeneratedMissionTemplate {
        let params = ObjectHuntParams(targetClasses: targets, requiredCount: required)
        let json = (try? MissionParameterEncoder.encode(params)) ?? "{}"
        return GeneratedMissionTemplate(
            id: UUID(uuidString: "33333333-0000-0000-0000-000000000004")!,
            kind: .objectHunt,
            difficulty: .medium,
            parametersJSON: json,
            title: "アイテム探し",
            subtitle: "身の回りで \(required) 個見つけよう",
            estimatedDurationSeconds: TimeInterval(required * 30),
            locale: "ja-JP",
            source: "sample",
            generatedAt: Date(timeIntervalSinceReferenceDate: 0),
            contentHash: "sample-hunt-\(required)"
        )
    }

    public static func portfolio() -> [GeneratedMissionTemplate] {
        [
            pushup(),
            math(),
            shake(),
            objectHunt()
        ]
    }
}
