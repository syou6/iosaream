import Foundation
import OkiMissionCore

public struct AnalyticsEvent: Sendable, Equatable {
    public let name: String
    public let properties: [String: AnalyticsValue]
    public let recordedAt: Date

    public init(name: String, properties: [String: AnalyticsValue] = [:], recordedAt: Date = Date()) {
        self.name = name
        self.properties = properties
        self.recordedAt = recordedAt
    }
}

public enum AnalyticsValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}

public protocol AnalyticsTracking: Sendable {
    func track(_ event: AnalyticsEvent) async
    func identify(userId: String, traits: [String: AnalyticsValue]) async
    func reset() async
    func flush() async
}

public extension AnalyticsTracking {
    func track(_ name: String, properties: [String: AnalyticsValue] = [:]) async {
        await track(AnalyticsEvent(name: name, properties: properties))
    }
}

public enum AnalyticsEventName {
    public static let appLaunched = "app_launched"
    public static let onboardingCompleted = "onboarding_completed"
    public static let alarmCreated = "alarm_created"
    public static let alarmEdited = "alarm_edited"
    public static let alarmDeleted = "alarm_deleted"
    public static let alarmFired = "alarm_fired"
    public static let missionStarted = "mission_started"
    public static let missionCompleted = "mission_completed"
    public static let missionFailed = "mission_failed"
    public static let missionCheated = "mission_cheated"
    public static let paywallViewed = "paywall_viewed"
    public static let paywallDismissed = "paywall_dismissed"
    public static let purchaseStarted = "purchase_started"
    public static let purchaseSucceeded = "purchase_succeeded"
    public static let purchaseFailed = "purchase_failed"
    public static let purchaseCancelled = "purchase_cancelled"
    public static let streakIncreased = "streak_increased"
    public static let streakBroken = "streak_broken"
    public static let tokushohoViewed = "tokushoho_viewed"
}
