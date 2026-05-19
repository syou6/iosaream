import Foundation

public enum FormStrictness: String, Sendable, Codable, CaseIterable {
    case lenient
    case moderate
    case strict
}

public struct PushupParams: Sendable, Equatable, Codable {
    public var reps: Int
    public var formStrictness: FormStrictness
    public var maxDurationSeconds: TimeInterval

    public init(reps: Int, formStrictness: FormStrictness = .moderate, maxDurationSeconds: TimeInterval = 120) {
        self.reps = reps
        self.formStrictness = formStrictness
        self.maxDurationSeconds = maxDurationSeconds
    }
}

public struct SquatParams: Sendable, Equatable, Codable {
    public var reps: Int
    public var formStrictness: FormStrictness
    public var maxDurationSeconds: TimeInterval

    public init(reps: Int, formStrictness: FormStrictness = .moderate, maxDurationSeconds: TimeInterval = 120) {
        self.reps = reps
        self.formStrictness = formStrictness
        self.maxDurationSeconds = maxDurationSeconds
    }
}

public enum MathOperator: String, Sendable, Codable, CaseIterable {
    case add
    case subtract
    case multiply
}

public struct MathParams: Sendable, Equatable, Codable {
    public var problemCount: Int
    public var operatorTypes: [MathOperator]
    public var minOperand: Int
    public var maxOperand: Int
    public var maxDurationSeconds: TimeInterval

    public init(
        problemCount: Int,
        operatorTypes: [MathOperator],
        minOperand: Int,
        maxOperand: Int,
        maxDurationSeconds: TimeInterval = 60
    ) {
        self.problemCount = problemCount
        self.operatorTypes = operatorTypes
        self.minOperand = minOperand
        self.maxOperand = maxOperand
        self.maxDurationSeconds = maxDurationSeconds
    }
}

public struct ShakeParams: Sendable, Equatable, Codable {
    public var requiredShakes: Int
    public var minMagnitude: Double
    public var maxDurationSeconds: TimeInterval

    public init(requiredShakes: Int, minMagnitude: Double = 1.8, maxDurationSeconds: TimeInterval = 30) {
        self.requiredShakes = requiredShakes
        self.minMagnitude = minMagnitude
        self.maxDurationSeconds = maxDurationSeconds
    }
}

public struct ObjectHuntParams: Sendable, Equatable, Codable {
    public var targetClasses: [String]
    public var requiredCount: Int
    public var maxDurationSeconds: TimeInterval

    public init(targetClasses: [String], requiredCount: Int, maxDurationSeconds: TimeInterval = 90) {
        self.targetClasses = targetClasses
        self.requiredCount = requiredCount
        self.maxDurationSeconds = maxDurationSeconds
    }
}

public struct BarcodeParams: Sendable, Equatable, Codable {
    public var targetCount: Int
    public var maxDurationSeconds: TimeInterval

    public init(targetCount: Int = 1, maxDurationSeconds: TimeInterval = 60) {
        self.targetCount = targetCount
        self.maxDurationSeconds = maxDurationSeconds
    }
}

public enum MissionParameterDecoder {
    public static func decode<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(type, from: data)
    }
}

public enum MissionParameterEncoder {
    public static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}
