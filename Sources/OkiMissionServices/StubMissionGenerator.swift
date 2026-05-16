import Foundation
import OkiMissionCore

public struct StubMissionGenerator: MissionGenerating {
    public let source: String

    public init(source: String = "stub") {
        self.source = source
    }

    public func generate(_ request: MissionGenerationRequest) async throws -> GeneratedMissionTemplate {
        let kind = pickKind(for: request)
        let template = try makeTemplate(kind: kind, difficulty: request.difficultyHint, locale: request.locale)
        return template
    }

    private func pickKind(for request: MissionGenerationRequest) -> MissionKind {
        var pool: [MissionKind]
        if let preferred = request.preferredKinds, !preferred.isEmpty {
            pool = preferred
        } else {
            pool = MissionKind.allCases
        }
        if let disabled = request.disabledKinds {
            pool.removeAll(where: disabled.contains)
        }
        if pool.isEmpty { pool = MissionKind.allCases }

        let avoid = Set(request.recentKinds.suffix(2))
        let candidates = pool.filter { !avoid.contains($0) }
        return (candidates.isEmpty ? pool : candidates).randomElement() ?? .math
    }

    private func makeTemplate(
        kind: MissionKind,
        difficulty: Difficulty,
        locale: String
    ) throws -> GeneratedMissionTemplate {
        let parametersJSON: String
        let title: String
        let duration: TimeInterval

        switch kind {
        case .pushup:
            let reps = repsForDifficulty(difficulty, base: 5)
            parametersJSON = try MissionParameterEncoder.encode(PushupParams(reps: reps))
            title = locale.hasPrefix("ja") ? "\(reps)回の腕立て伏せ" : "\(reps) pushups"
            duration = TimeInterval(reps * 6)

        case .squat:
            let reps = repsForDifficulty(difficulty, base: 8)
            parametersJSON = try MissionParameterEncoder.encode(SquatParams(reps: reps))
            title = locale.hasPrefix("ja") ? "\(reps)回のスクワット" : "\(reps) squats"
            duration = TimeInterval(reps * 5)

        case .math:
            let count = repsForDifficulty(difficulty, base: 3)
            let max = difficulty == .hard ? 20 : (difficulty == .medium ? 12 : 9)
            let operators: [MathOperator] = difficulty == .easy ? [.add] : [.add, .subtract, .multiply]
            parametersJSON = try MissionParameterEncoder.encode(
                MathParams(problemCount: count, operatorTypes: operators, minOperand: 1, maxOperand: max)
            )
            title = locale.hasPrefix("ja") ? "計算 \(count) 問" : "\(count) math problems"
            duration = TimeInterval(count * 10)

        case .shake:
            let shakes = repsForDifficulty(difficulty, base: 10)
            parametersJSON = try MissionParameterEncoder.encode(ShakeParams(requiredShakes: shakes))
            title = locale.hasPrefix("ja") ? "\(shakes) 回シェイク" : "Shake \(shakes) times"
            duration = TimeInterval(shakes)

        case .objectHunt:
            let count = difficulty == .hard ? 3 : (difficulty == .medium ? 2 : 1)
            parametersJSON = try MissionParameterEncoder.encode(
                ObjectHuntParams(targetClasses: ["remote_control", "book", "wallet"], requiredCount: count)
            )
            title = locale.hasPrefix("ja") ? "身の回りのアイテムを \(count) 個" : "Find \(count) items"
            duration = TimeInterval(count * 30)

        case .barcode:
            parametersJSON = try MissionParameterEncoder.encode(BarcodeParams())
            title = locale.hasPrefix("ja") ? "バーコードをスキャン" : "Scan a barcode"
            duration = 45
        }

        let contentHash = stableHash("\(kind.rawValue)|\(difficulty.rawValue)|\(parametersJSON)")
        return GeneratedMissionTemplate(
            kind: kind,
            difficulty: difficulty,
            parametersJSON: parametersJSON,
            title: title,
            estimatedDurationSeconds: duration,
            locale: locale,
            source: source,
            contentHash: contentHash
        )
    }

    private func repsForDifficulty(_ difficulty: Difficulty, base: Int) -> Int {
        switch difficulty {
        case .easy: return base
        case .medium: return Int(Double(base) * 1.5)
        case .hard: return base * 2
        }
    }

    private func stableHash(_ input: String) -> String {
        var hasher = Hasher()
        hasher.combine(input)
        let value = hasher.finalize()
        return String(UInt(bitPattern: value), radix: 16)
    }
}
