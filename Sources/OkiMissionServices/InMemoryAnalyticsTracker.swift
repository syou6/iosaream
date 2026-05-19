import Foundation
import OkiMissionCore

public actor InMemoryAnalyticsTracker: AnalyticsTracking {
    public private(set) var events: [AnalyticsEvent] = []
    public private(set) var userId: String?
    public private(set) var traits: [String: AnalyticsValue] = [:]
    public private(set) var flushCount: Int = 0

    public init() {}

    public func track(_ event: AnalyticsEvent) async {
        events.append(event)
    }

    public func identify(userId: String, traits: [String: AnalyticsValue]) async {
        self.userId = userId
        self.traits = traits
    }

    public func reset() async {
        events.removeAll()
        userId = nil
        traits.removeAll()
        flushCount = 0
    }

    public func flush() async {
        flushCount += 1
    }

    public func eventNames() -> [String] {
        events.map(\.name)
    }
}
