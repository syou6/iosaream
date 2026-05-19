import Foundation
import SwiftData
import OkiMissionCore

@Model
public final class AlarmEntity {
    @Attribute(.unique) public var id: UUID
    public var alarmKitId: UUID?
    public var label: String
    public var scheduleKind: AlarmScheduleKind
    public var fireDate: Date?
    public var timeOfDayHour: Int?
    public var timeOfDayMinute: Int?
    public var weekdayMaskRaw: Int
    public var countdownSeconds: Int?
    public var soundId: String
    public var missionTemplateId: UUID?
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        alarmKitId: UUID? = nil,
        label: String,
        scheduleKind: AlarmScheduleKind,
        fireDate: Date? = nil,
        timeOfDayHour: Int? = nil,
        timeOfDayMinute: Int? = nil,
        weekdayMaskRaw: Int = 0,
        countdownSeconds: Int? = nil,
        soundId: String,
        missionTemplateId: UUID? = nil,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.alarmKitId = alarmKitId
        self.label = label
        self.scheduleKind = scheduleKind
        self.fireDate = fireDate
        self.timeOfDayHour = timeOfDayHour
        self.timeOfDayMinute = timeOfDayMinute
        self.weekdayMaskRaw = weekdayMaskRaw
        self.countdownSeconds = countdownSeconds
        self.soundId = soundId
        self.missionTemplateId = missionTemplateId
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
