import Foundation

public struct AlarmSpec: Equatable, Sendable, Codable, Identifiable {
    public let id: UUID
    public var label: String
    public var scheduleKind: AlarmScheduleKind
    public var fireDate: Date?
    public var timeOfDay: TimeOfDay?
    public var weekdayMask: WeekdayMask
    public var countdownSeconds: Int?
    public var soundId: String
    public var missionTemplateId: UUID?
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        label: String,
        scheduleKind: AlarmScheduleKind,
        fireDate: Date? = nil,
        timeOfDay: TimeOfDay? = nil,
        weekdayMask: WeekdayMask = .empty,
        countdownSeconds: Int? = nil,
        soundId: String,
        missionTemplateId: UUID? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.label = label
        self.scheduleKind = scheduleKind
        self.fireDate = fireDate
        self.timeOfDay = timeOfDay
        self.weekdayMask = weekdayMask
        self.countdownSeconds = countdownSeconds
        self.soundId = soundId
        self.missionTemplateId = missionTemplateId
        self.isEnabled = isEnabled
    }

    public func validate() throws {
        switch scheduleKind {
        case .oneShot:
            if fireDate == nil { throw DomainError.invalidAlarmConfig }
        case .recurringWeekly:
            if timeOfDay == nil || weekdayMask.isEmpty { throw DomainError.invalidAlarmConfig }
        case .countdown:
            if let seconds = countdownSeconds {
                if seconds <= 0 { throw DomainError.invalidAlarmConfig }
            } else {
                throw DomainError.invalidAlarmConfig
            }
        }
    }
}
