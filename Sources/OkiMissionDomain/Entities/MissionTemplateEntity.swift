import Foundation
import SwiftData
import OkiMissionCore

@Model
public final class MissionTemplateEntity {
    @Attribute(.unique) public var id: UUID
    public var missionKind: MissionKind
    public var difficulty: Difficulty
    public var parametersJSON: String
    public var parametersVersion: Int
    public var locale: String
    public var source: String
    public var generatedAt: Date
    public var validUntil: Date?
    public var contentHash: String

    public init(
        id: UUID = UUID(),
        missionKind: MissionKind,
        difficulty: Difficulty,
        parametersJSON: String,
        parametersVersion: Int = 1,
        locale: String,
        source: String,
        generatedAt: Date = Date(),
        validUntil: Date? = nil,
        contentHash: String
    ) {
        self.id = id
        self.missionKind = missionKind
        self.difficulty = difficulty
        self.parametersJSON = parametersJSON
        self.parametersVersion = parametersVersion
        self.locale = locale
        self.source = source
        self.generatedAt = generatedAt
        self.validUntil = validUntil
        self.contentHash = contentHash
    }
}
