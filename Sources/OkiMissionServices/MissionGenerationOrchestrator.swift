import Foundation
import OkiMissionCore

public struct MissionGenerationOrchestrator: MissionGenerating {
    public enum Source: Sendable, Equatable {
        case primary
        case fallback
    }

    private let primary: any MissionGenerating
    private let fallback: any MissionGenerating
    private let onSourceUsed: (@Sendable (Source) -> Void)?

    public init(
        primary: any MissionGenerating,
        fallback: any MissionGenerating,
        onSourceUsed: (@Sendable (Source) -> Void)? = nil
    ) {
        self.primary = primary
        self.fallback = fallback
        self.onSourceUsed = onSourceUsed
    }

    public func generate(_ request: MissionGenerationRequest) async throws -> GeneratedMissionTemplate {
        do {
            let template = try await primary.generate(request)
            onSourceUsed?(.primary)
            return template
        } catch {
            let template = try await fallback.generate(request)
            onSourceUsed?(.fallback)
            return template
        }
    }
}
