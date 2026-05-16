import Foundation
import OkiMissionCore

public actor InMemoryAlarmService: AlarmServicing {
    private var authorization: AlarmAuthorizationState
    private var domainToKit: [UUID: UUID] = [:]
    private var kitToDomain: [UUID: UUID] = [:]
    private var scheduledSpecs: [UUID: AlarmSpec] = [:]
    private let continuation: AsyncStream<AlarmEvent>.Continuation
    public nonisolated let events: AsyncStream<AlarmEvent>

    public init(initialAuthorization: AlarmAuthorizationState = .notDetermined) {
        self.authorization = initialAuthorization
        let (stream, continuation) = AsyncStream.makeStream(of: AlarmEvent.self)
        self.events = stream
        self.continuation = continuation
    }

    public func requestAuthorization() async throws -> AlarmAuthorizationState {
        if authorization == .notDetermined {
            authorization = .authorized
        }
        if authorization == .denied {
            continuation.yield(.authorizationDenied)
        }
        return authorization
    }

    public func authorizationState() async -> AlarmAuthorizationState {
        authorization
    }

    @discardableResult
    public func schedule(_ spec: AlarmSpec) async throws -> UUID {
        try spec.validate()
        guard authorization == .authorized else {
            throw DomainError.capabilityDenied(.alarm)
        }
        let kitId = UUID()
        domainToKit[spec.id] = kitId
        kitToDomain[kitId] = spec.id
        scheduledSpecs[spec.id] = spec
        continuation.yield(.scheduled(domainId: spec.id, kitId: kitId))
        continuation.yield(.stateChanged(domainId: spec.id, state: .scheduled))
        return kitId
    }

    public func cancel(domainAlarmId: UUID) async throws {
        if let kitId = domainToKit.removeValue(forKey: domainAlarmId) {
            kitToDomain.removeValue(forKey: kitId)
        }
        scheduledSpecs.removeValue(forKey: domainAlarmId)
        continuation.yield(.cancelled(domainId: domainAlarmId))
    }

    public func cancelAll() async throws {
        let domainIds = Array(domainToKit.keys)
        domainToKit.removeAll()
        kitToDomain.removeAll()
        scheduledSpecs.removeAll()
        for id in domainIds {
            continuation.yield(.cancelled(domainId: id))
        }
    }

    public func scheduledAlarmKitIds() async -> [UUID] {
        Array(kitToDomain.keys)
    }

    public func setAuthorization(_ state: AlarmAuthorizationState) {
        self.authorization = state
        if state == .denied {
            continuation.yield(.authorizationDenied)
        }
    }

    public func simulateFire(domainAlarmId: UUID) {
        guard scheduledSpecs[domainAlarmId] != nil else { return }
        continuation.yield(.stateChanged(domainId: domainAlarmId, state: .alerting))
    }

    public func simulateDismissalWithoutMission(domainAlarmId: UUID, at date: Date = Date()) {
        continuation.yield(.dismissedWithoutMission(domainId: domainAlarmId, at: date))
    }
}
