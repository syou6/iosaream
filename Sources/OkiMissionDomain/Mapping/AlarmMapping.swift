import Foundation
import OkiMissionCore

public extension AlarmSpec {
    init(entity: AlarmEntity) {
        let timeOfDay: TimeOfDay?
        if let h = entity.timeOfDayHour, let m = entity.timeOfDayMinute {
            timeOfDay = TimeOfDay(hour: h, minute: m)
        } else {
            timeOfDay = nil
        }
        self.init(
            id: entity.id,
            label: entity.label,
            scheduleKind: entity.scheduleKind,
            fireDate: entity.fireDate,
            timeOfDay: timeOfDay,
            weekdayMask: WeekdayMask(rawValue: entity.weekdayMaskRaw),
            countdownSeconds: entity.countdownSeconds,
            soundId: entity.soundId,
            missionTemplateId: entity.missionTemplateId,
            isEnabled: entity.isEnabled
        )
    }
}

public extension AlarmEntity {
    func apply(spec: AlarmSpec, now: Date = Date()) {
        self.label = spec.label
        self.scheduleKind = spec.scheduleKind
        self.fireDate = spec.fireDate
        self.timeOfDayHour = spec.timeOfDay?.hour
        self.timeOfDayMinute = spec.timeOfDay?.minute
        self.weekdayMaskRaw = spec.weekdayMask.rawValue
        self.countdownSeconds = spec.countdownSeconds
        self.soundId = spec.soundId
        self.missionTemplateId = spec.missionTemplateId
        self.isEnabled = spec.isEnabled
        self.updatedAt = now
    }

    static func make(from spec: AlarmSpec, now: Date = Date()) -> AlarmEntity {
        AlarmEntity(
            id: spec.id,
            label: spec.label,
            scheduleKind: spec.scheduleKind,
            fireDate: spec.fireDate,
            timeOfDayHour: spec.timeOfDay?.hour,
            timeOfDayMinute: spec.timeOfDay?.minute,
            weekdayMaskRaw: spec.weekdayMask.rawValue,
            countdownSeconds: spec.countdownSeconds,
            soundId: spec.soundId,
            missionTemplateId: spec.missionTemplateId,
            isEnabled: spec.isEnabled,
            createdAt: now,
            updatedAt: now
        )
    }
}
