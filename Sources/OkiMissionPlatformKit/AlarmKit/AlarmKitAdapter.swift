import Foundation
import OkiMissionCore
import OkiMissionServices

// MARK: - AlarmKit live adapter
//
// IMPORTANT: this file is the best-effort live implementation of
// AlarmServicing against Apple's AlarmKit framework. The framework was
// previewed at WWDC 2025 but the public API names may shift between
// Xcode 26 betas. Verify the following symbols when the SDK is
// available and adjust as needed:
//
//   - AlarmManager.shared / .requestAuthorization()
//   - AlarmConfiguration<Metadata>
//   - AlarmAttributes(presentation:metadata:tintColor:)
//   - AlarmPresentation.alert/countdown
//   - AlarmPresentation.Alert(title:stopButton:secondaryButton:secondaryButtonBehavior:)
//   - AlertConfiguration.Sound.named(_:)
//   - Alarm.Schedule.fixed(_:) / .relative(.init(time:, repeats:))
//   - Alarm.CountdownDuration(preAlert:postAlert:)
//   - AlarmManager.schedule(_:) -> Alarm<Metadata>
//   - AlarmManager.cancel(_:)
//   - AlarmManager.alarmUpdates  (AsyncSequence)
//
// The AppIntent classes (StopAlarmIntent, StartMissionIntent) live in
// the App target so they can route to the SwiftUI navigation layer.

#if canImport(AlarmKit) && os(iOS)
import AlarmKit

public struct AlarmMetadataPayload: AlarmMetadata, Sendable {
    public let domainAlarmId: UUID
    public let missionTemplateId: UUID?

    public init(domainAlarmId: UUID, missionTemplateId: UUID?) {
        self.domainAlarmId = domainAlarmId
        self.missionTemplateId = missionTemplateId
    }
}

public actor AlarmKitAdapter: AlarmServicing {
    public typealias StopIntentFactory = @Sendable (UUID) -> any LiveActivityIntent
    public typealias SecondaryIntentFactory = @Sendable (UUID) -> any LiveActivityIntent

    private let manager: AlarmManager
    private let stopIntentFactory: StopIntentFactory
    private let secondaryIntentFactory: SecondaryIntentFactory?

    private var domainToKit: [UUID: UUID] = [:]
    private var kitToDomain: [UUID: UUID] = [:]
    private let continuation: AsyncStream<AlarmEvent>.Continuation
    public nonisolated let events: AsyncStream<AlarmEvent>
    private var updatesTask: Task<Void, Never>?

    public init(
        manager: AlarmManager = AlarmManager.shared,
        stopIntentFactory: @escaping StopIntentFactory,
        secondaryIntentFactory: SecondaryIntentFactory? = nil
    ) {
        self.manager = manager
        self.stopIntentFactory = stopIntentFactory
        self.secondaryIntentFactory = secondaryIntentFactory
        let (stream, continuation) = AsyncStream.makeStream(of: AlarmEvent.self)
        self.events = stream
        self.continuation = continuation
    }

    public func requestAuthorization() async throws -> AlarmAuthorizationState {
        let state = try await manager.requestAuthorization()
        switch state {
        case .authorized: return .authorized
        case .denied:
            continuation.yield(.authorizationDenied)
            return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    public func authorizationState() async -> AlarmAuthorizationState {
        switch await manager.authorizationState {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    @discardableResult
    public func schedule(_ spec: AlarmSpec) async throws -> UUID {
        try spec.validate()
        let configuration = try buildConfiguration(from: spec)
        let scheduled = try await manager.schedule(configuration)
        let kitId = scheduled.id
        domainToKit[spec.id] = kitId
        kitToDomain[kitId] = spec.id
        continuation.yield(.scheduled(domainId: spec.id, kitId: kitId))
        continuation.yield(.stateChanged(domainId: spec.id, state: .scheduled))
        return kitId
    }

    public func cancel(domainAlarmId: UUID) async throws {
        guard let kitId = domainToKit.removeValue(forKey: domainAlarmId) else { return }
        kitToDomain.removeValue(forKey: kitId)
        try await manager.cancel(kitId)
        continuation.yield(.cancelled(domainId: domainAlarmId))
    }

    public func cancelAll() async throws {
        let mapping = domainToKit
        domainToKit.removeAll()
        kitToDomain.removeAll()
        for (domainId, kitId) in mapping {
            try? await manager.cancel(kitId)
            continuation.yield(.cancelled(domainId: domainId))
        }
    }

    public func scheduledAlarmKitIds() async -> [UUID] {
        Array(kitToDomain.keys)
    }

    public func bootstrap() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in manager.alarmUpdates {
                await self.process(snapshot: snapshot)
            }
        }
    }

    public func teardown() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    private func process(snapshot: [Alarm<AlarmMetadataPayload>]) {
        var seenKitIds = Set<UUID>()
        for alarm in snapshot {
            seenKitIds.insert(alarm.id)
            let domainId = kitToDomain[alarm.id] ?? alarm.attributes.metadata.domainAlarmId
            kitToDomain[alarm.id] = domainId
            domainToKit[domainId] = alarm.id
            let mapped = AlarmKitAdapter.mapState(alarm.state)
            continuation.yield(.stateChanged(domainId: domainId, state: mapped))
        }
        let removed = Set(kitToDomain.keys).subtracting(seenKitIds)
        for kitId in removed {
            if let domainId = kitToDomain.removeValue(forKey: kitId) {
                domainToKit.removeValue(forKey: domainId)
                continuation.yield(.cancelled(domainId: domainId))
            }
        }
    }

    private func buildConfiguration(from spec: AlarmSpec) throws -> AlarmConfiguration<AlarmMetadataPayload> {
        let metadata = AlarmMetadataPayload(
            domainAlarmId: spec.id,
            missionTemplateId: spec.missionTemplateId
        )

        let stopButton = AlarmPresentation.Button(
            text: LocalizedStringResource(stringLiteral: "停止"),
            textColor: .white,
            systemImageName: "stop.fill"
        )
        let secondaryButton: AlarmPresentation.Button? = spec.missionTemplateId != nil
            ? AlarmPresentation.Button(
                text: LocalizedStringResource(stringLiteral: "ミッション"),
                textColor: .white,
                systemImageName: "play.fill"
            )
            : nil

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: spec.label),
            stopButton: stopButton,
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: .custom
        )

        let presentation = AlarmPresentation(alert: alert)
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: metadata,
            tintColor: .accentColor
        )
        let sound: AlertConfiguration.Sound = .named(spec.soundId + ".caf")
        let stopIntent = stopIntentFactory(spec.id)
        let secondaryIntent = secondaryIntentFactory?(spec.id)

        switch spec.scheduleKind {
        case .oneShot:
            guard let fireDate = spec.fireDate else { throw DomainError.invalidAlarmConfig }
            return AlarmConfiguration(
                schedule: .fixed(fireDate),
                attributes: attributes,
                sound: sound,
                stopIntent: stopIntent,
                secondaryIntent: secondaryIntent
            )
        case .recurringWeekly:
            guard let time = spec.timeOfDay, !spec.weekdayMask.isEmpty else {
                throw DomainError.invalidAlarmConfig
            }
            let weekdays = spec.weekdayMask.decoded().map(AlarmKitAdapter.weekday(from:))
            let relative = Alarm.Schedule.Relative(
                time: .init(hour: time.hour, minute: time.minute),
                repeats: .weekly(weekdays)
            )
            return AlarmConfiguration(
                schedule: .relative(relative),
                attributes: attributes,
                sound: sound,
                stopIntent: stopIntent,
                secondaryIntent: secondaryIntent
            )
        case .countdown:
            guard let seconds = spec.countdownSeconds, seconds > 0 else {
                throw DomainError.invalidAlarmConfig
            }
            let duration = Alarm.CountdownDuration(preAlert: TimeInterval(seconds), postAlert: 60)
            return AlarmConfiguration(
                countdownDuration: duration,
                attributes: attributes,
                sound: sound,
                stopIntent: stopIntent,
                secondaryIntent: secondaryIntent
            )
        }
    }

    private static func mapState(_ kitState: Alarm<AlarmMetadataPayload>.State) -> AlarmKitState {
        switch kitState {
        case .scheduled: return .scheduled
        case .alerting: return .alerting
        case .paused: return .paused
        case .completed: return .completed
        case .cancelled: return .cancelled
        @unknown default: return .scheduled
        }
    }

    private static func weekday(from domainWeekday: Weekday) -> Locale.Weekday {
        switch domainWeekday {
        case .sunday: return .sunday
        case .monday: return .monday
        case .tuesday: return .tuesday
        case .wednesday: return .wednesday
        case .thursday: return .thursday
        case .friday: return .friday
        case .saturday: return .saturday
        }
    }
}
#endif
