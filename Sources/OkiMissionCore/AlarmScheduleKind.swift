import Foundation

public enum AlarmScheduleKind: String, Codable, Sendable, CaseIterable {
    case oneShot
    case recurringWeekly
    case countdown
}

public struct TimeOfDay: Equatable, Hashable, Sendable, Codable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        precondition((0..<24).contains(hour), "hour out of range")
        precondition((0..<60).contains(minute), "minute out of range")
        self.hour = hour
        self.minute = minute
    }
}
