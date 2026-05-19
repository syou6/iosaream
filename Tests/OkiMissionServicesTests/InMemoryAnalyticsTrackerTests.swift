import Testing
import Foundation
@testable import OkiMissionServices

@Suite("InMemoryAnalyticsTracker")
struct InMemoryAnalyticsTrackerTests {
    @Test("records tracked events in order")
    func tracksInOrder() async {
        let tracker = InMemoryAnalyticsTracker()
        await tracker.track(AnalyticsEventName.appLaunched)
        await tracker.track(AnalyticsEventName.alarmCreated, properties: ["kind": .string("oneShot")])
        let names = await tracker.eventNames()
        #expect(names == [AnalyticsEventName.appLaunched, AnalyticsEventName.alarmCreated])
    }

    @Test("identify stores user id and traits")
    func identify() async {
        let tracker = InMemoryAnalyticsTracker()
        await tracker.identify(userId: "u_123", traits: ["tier": .string("pro")])
        let id = await tracker.userId
        let traits = await tracker.traits
        #expect(id == "u_123")
        #expect(traits["tier"] == .string("pro"))
    }

    @Test("reset clears everything")
    func reset() async {
        let tracker = InMemoryAnalyticsTracker()
        await tracker.track(AnalyticsEventName.appLaunched)
        await tracker.identify(userId: "u_1", traits: [:])
        await tracker.flush()
        await tracker.reset()
        let events = await tracker.events
        let id = await tracker.userId
        let flushCount = await tracker.flushCount
        #expect(events.isEmpty)
        #expect(id == nil)
        #expect(flushCount == 0)
    }

    @Test("flush increments count")
    func flushIncrements() async {
        let tracker = InMemoryAnalyticsTracker()
        await tracker.flush()
        await tracker.flush()
        let count = await tracker.flushCount
        #expect(count == 2)
    }
}
