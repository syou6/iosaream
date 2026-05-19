import Foundation
import OkiMissionCore
import OkiMissionServices

// MARK: - AlarmKit live adapter
//
// Rewritten against the shipped iOS 26.4 AlarmKit interface:
//
//   - AlarmManager.shared / .schedule(id:configuration:) / .cancel / .stop
//   - AlarmManager.AlarmConfiguration<Metadata> with .alarm(...) / .timer(...)
//   - Alarm is NOT generic — id, schedule, countdownDuration, state only
//   - Alarm.State = .scheduled / .countdown / .paused / .alerting
//   - cancel / stop / pause / resume are synchronous throws
//   - alarmUpdates is AsyncSequence<[Alarm], Never>
//   - LiveActivityIntent comes from AppIntents
//   - AlarmButton is top-level (not AlarmPresentation.Button)
//   - Sound type: ActivityKit.AlertConfiguration.AlertSound

#if canImport(AlarmKit) && os(iOS)
import AlarmKit
import AppIntents
import ActivityKit
import SwiftUI

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

    nonisolated(unsafe) private let manager: AlarmManager
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
        switch manager.authorizationState {
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
        let scheduled = try await manager.schedule(id: spec.id, configuration: configuration)
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
        try manager.cancel(id: kitId)
        continuation.yield(.cancelled(domainId: domainAlarmId))
    }

    public func cancelAll() async throws {
        let mapping = domainToKit
        domainToKit.removeAll()
        kitToDomain.removeAll()
        for (domainId, kitId) in mapping {
            try? manager.cancel(id: kitId)
            continuation.yield(.cancelled(domainId: domainId))
        }
    }

    public func scheduledAlarmKitIds() async -> [UUID] {
        Array(kitToDomain.keys)
    }

    public func bootstrap() {
        updatesTask?.cancel()
        nonisolated(unsafe) let manager = self.manager
        nonisolated(unsafe) weak var weakSelf = self
        updatesTask = Task {
            for await snapshot in manager.alarmUpdates {
                guard let self = weakSelf else { return }
                await self.process(snapshot: snapshot)
            }
        }
    }

    public func teardown() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    private func process(snapshot: [Alarm]) {
        var seenKitIds = Set<UUID>()
        for alarm in snapshot {
            seenKitIds.insert(alarm.id)
            guard let domainId = kitToDomain[alarm.id] else { continue }
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

    private func buildConfiguration(
        from spec: AlarmSpec
    ) throws -> sending AlarmManager.AlarmConfiguration<AlarmMetadataPayload> {
        let metadata = AlarmMetadataPayload(
            domainAlarmId: spec.id,
            missionTemplateId: spec.missionTemplateId
        )

        let secondaryButton: AlarmButton? = spec.missionTemplateId != nil
            ? AlarmButton(
                text: LocalizedStringResource(stringLiteral: "ミッション"),
                textColor: .white,
                systemImageName: "play.fill"
            )
            : nil

        let stopButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "停止"),
            textColor: .white,
            systemImageName: "stop.fill"
        )
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: spec.label),
            stopButton: stopButton,
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: secondaryButton == nil ? nil : .custom
        )

        let presentation = AlarmPresentation(alert: alert)
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: metadata,
            tintColor: .accentColor
        )

        let sound: AlertConfiguration.AlertSound = .named(spec.soundId)
        let stopIntent = stopIntentFactory(spec.id)
        let secondaryIntent = secondaryIntentFactory?(spec.id)

        switch spec.scheduleKind {
        case .oneShot:
            guard let fireDate = spec.fireDate else { throw DomainError.invalidAlarmConfig }
            return .alarm(
                schedule: .fixed(fireDate),
                attributes: attributes,
                stopIntent: stopIntent,
                secondaryIntent: secondaryIntent,
                sound: sound
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
            return .alarm(
                schedule: .relative(relative),
                attributes: attributes,
                stopIntent: stopIntent,
                secondaryIntent: secondaryIntent,
                sound: sound
            )

        case .countdown:
            guard let seconds = spec.countdownSeconds, seconds > 0 else {
                throw DomainError.invalidAlarmConfig
            }
            return .timer(
                duration: TimeInterval(seconds),
                attributes: attributes,
                stopIntent: stopIntent,
                secondaryIntent: secondaryIntent,
                sound: sound
            )
        }
    }

    private static func mapState(_ kitState: Alarm.State) -> AlarmKitState {
        switch kitState {
        case .scheduled: return .scheduled
        case .alerting: return .alerting
        case .paused: return .paused
        case .countdown: return .scheduled
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
