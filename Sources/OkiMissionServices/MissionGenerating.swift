import Foundation
import OkiMissionCore

public protocol MissionGenerating: Sendable {
    func generate(_ request: MissionGenerationRequest) async throws -> GeneratedMissionTemplate
}
