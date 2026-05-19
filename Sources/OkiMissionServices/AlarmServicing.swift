import Foundation
import OkiMissionCore

public enum AlarmKitState: String, Sendable, Codable {
    case scheduled
    case alerting
    case paused
    case completed
    case cancelled
}

public enum AlarmEvent: Sendable, Equatable {
    case scheduled(domainId: UUID, kitId: UUID)
    case cancelled(domainId: UUID)
    case stateChanged(domainId: UUID, state: AlarmKitState)
    case dismissedWithoutMission(domainId: UUID, at: Date)
    case authorizationDenied
}

public enum AlarmAuthorizationState: String, Sendable, Codable {
    case notDetermined
    case authorized
    case denied
}

public protocol AlarmServicing: Sendable {
    func requestAuthorization() async throws -> AlarmAuthorizationState
    func authorizationState() async -> AlarmAuthorizationState

    @discardableResult
    func schedule(_ spec: AlarmSpec) async throws -> UUID
    func cancel(domainAlarmId: UUID) async throws
    func cancelAll() async throws
    func scheduledAlarmKitIds() async -> [UUID]

    var events: AsyncStream<AlarmEvent> { get }
}
