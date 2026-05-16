import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionServices

@Suite("InMemoryAlarmService")
struct InMemoryAlarmServiceTests {
    @Test("default state requires authorization before scheduling")
    func authorizationGate() async throws {
        let service = InMemoryAlarmService(initialAuthorization: .denied)
        let spec = AlarmSpec(
            label: "Morning",
            scheduleKind: .oneShot,
            fireDate: Date(timeIntervalSinceNow: 60),
            soundId: "default"
        )
        await #expect(throws: DomainError.capabilityDenied(.alarm)) {
            _ = try await service.schedule(spec)
        }
    }

    @Test("requestAuthorization transitions notDetermined to authorized")
    func authorizationFlow() async throws {
        let service = InMemoryAlarmService()
        let state = try await service.requestAuthorization()
        #expect(state == .authorized)
    }

    @Test("scheduling returns a kit id and stores mapping")
    func schedulingStoresMapping() async throws {
        let service = InMemoryAlarmService(initialAuthorization: .authorized)
        let spec = AlarmSpec(
            label: "Morning",
            scheduleKind: .oneShot,
            fireDate: Date(timeIntervalSinceNow: 60),
            soundId: "default"
        )
        let kitId = try await service.schedule(spec)
        let kitIds = await service.scheduledAlarmKitIds()
        #expect(kitIds.contains(kitId))
    }

    @Test("cancelling removes the mapping")
    func cancelRemovesMapping() async throws {
        let service = InMemoryAlarmService(initialAuthorization: .authorized)
        let spec = AlarmSpec(
            label: "Morning",
            scheduleKind: .oneShot,
            fireDate: Date(timeIntervalSinceNow: 60),
            soundId: "default"
        )
        _ = try await service.schedule(spec)
        try await service.cancel(domainAlarmId: spec.id)
        let kitIds = await service.scheduledAlarmKitIds()
        #expect(kitIds.isEmpty)
    }

    @Test("invalid spec throws before scheduling")
    func invalidSpecThrows() async throws {
        let service = InMemoryAlarmService(initialAuthorization: .authorized)
        let invalid = AlarmSpec(
            label: "Broken",
            scheduleKind: .oneShot,
            soundId: "default"
        )
        await #expect(throws: DomainError.invalidAlarmConfig) {
            _ = try await service.schedule(invalid)
        }
    }

    @Test("scheduling emits a scheduled event")
    func emitsEvent() async throws {
        let service = InMemoryAlarmService(initialAuthorization: .authorized)
        let spec = AlarmSpec(
            label: "Morning",
            scheduleKind: .oneShot,
            fireDate: Date(timeIntervalSinceNow: 60),
            soundId: "default"
        )

        let collector = EventCollector()
        let stream = service.events
        let task = Task {
            for await event in stream {
                await collector.append(event)
                if await collector.count >= 2 { break }
            }
        }

        _ = try await service.schedule(spec)
        _ = await task.value
        let events = await collector.events
        #expect(events.contains { event in
            if case .scheduled = event { return true }
            return false
        })
        #expect(events.contains { event in
            if case .stateChanged(_, .scheduled) = event { return true }
            return false
        })
    }
}

private actor EventCollector {
    var events: [AlarmEvent] = []
    var count: Int { events.count }
    func append(_ event: AlarmEvent) { events.append(event) }
}
