import Foundation
import OkiMissionCore

public struct MissionGenerationRequest: Sendable, Equatable, Codable {
    public var targetDate: Date
    public var difficultyHint: Difficulty
    public var recentKinds: [MissionKind]
    public var locale: String
    public var preferredKinds: [MissionKind]?
    public var disabledKinds: [MissionKind]?

    public init(
        targetDate: Date,
        difficultyHint: Difficulty,
        recentKinds: [MissionKind] = [],
        locale: String = "ja-JP",
        preferredKinds: [MissionKind]? = nil,
        disabledKinds: [MissionKind]? = nil
    ) {
        self.targetDate = targetDate
        self.difficultyHint = difficultyHint
        self.recentKinds = recentKinds
        self.locale = locale
        self.preferredKinds = preferredKinds
        self.disabledKinds = disabledKinds
    }
}

public struct GeneratedMissionTemplate: Sendable, Equatable, Codable {
    public let id: UUID
    public var kind: MissionKind
    public var difficulty: Difficulty
    public var parametersJSON: String
    public var parametersVersion: Int
    public var title: String
    public var subtitle: String?
    public var encouragement: String?
    public var estimatedDurationSeconds: TimeInterval
    public var locale: String
    public var source: String
    public var generatedAt: Date
    public var contentHash: String

    public init(
        id: UUID = UUID(),
        kind: MissionKind,
        difficulty: Difficulty,
        parametersJSON: String,
        parametersVersion: Int = 1,
        title: String,
        subtitle: String? = nil,
        encouragement: String? = nil,
        estimatedDurationSeconds: TimeInterval,
        locale: String,
        source: String,
        generatedAt: Date = Date(),
        contentHash: String
    ) {
        self.id = id
        self.kind = kind
        self.difficulty = difficulty
        self.parametersJSON = parametersJSON
        self.parametersVersion = parametersVersion
        self.title = title
        self.subtitle = subtitle
        self.encouragement = encouragement
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.locale = locale
        self.source = source
        self.generatedAt = generatedAt
        self.contentHash = contentHash
    }
}

public enum MissionGenerationError: Error, Equatable, Sendable {
    case rateLimited(remaining: Int)
    case providerUnavailable
    case decodingFailed(String)
}

public protocol MissionGenerating: Sendable {
    func generate(_ request: MissionGenerationRequest) async throws -> GeneratedMissionTemplate
}
