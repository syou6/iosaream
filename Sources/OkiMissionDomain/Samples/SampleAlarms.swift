import Foundation
import OkiMissionCore

public enum SampleAlarms {
    public static func morningWeekdays(now: Date = Date()) -> AlarmEntity {
        AlarmEntity(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000001")!,
            label: "起床",
            scheduleKind: .recurringWeekly,
            timeOfDayHour: 7,
            timeOfDayMinute: 0,
            weekdayMaskRaw: WeekdayMask.weekdays.rawValue,
            soundId: "sunrise",
            missionTemplateId: nil,
            isEnabled: true,
            createdAt: now,
            updatedAt: now
        )
    }

    public static func weekendLateMorning(now: Date = Date()) -> AlarmEntity {
        AlarmEntity(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000002")!,
            label: "週末ゆっくり",
            scheduleKind: .recurringWeekly,
            timeOfDayHour: 9,
            timeOfDayMinute: 30,
            weekdayMaskRaw: WeekdayMask.weekends.rawValue,
            soundId: "gentle",
            missionTemplateId: nil,
            isEnabled: true,
            createdAt: now,
            updatedAt: now
        )
    }

    public static func eveningOneShot(daysAhead: Int = 1, now: Date = Date()) -> AlarmEntity {
        let calendar = Calendar(identifier: .gregorian)
        let target = calendar.date(byAdding: .day, value: daysAhead, to: now)!
        var components = calendar.dateComponents([.year, .month, .day], from: target)
        components.hour = 18
        components.minute = 30
        let fireDate = calendar.date(from: components) ?? target
        return AlarmEntity(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000003")!,
            label: "夜のミーティング",
            scheduleKind: .oneShot,
            fireDate: fireDate,
            soundId: "chime",
            missionTemplateId: nil,
            isEnabled: true,
            createdAt: now,
            updatedAt: now
        )
    }

    public static func pomodoroCountdown(now: Date = Date()) -> AlarmEntity {
        AlarmEntity(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000004")!,
            label: "ポモドーロ",
            scheduleKind: .countdown,
            countdownSeconds: 25 * 60,
            soundId: "bell",
            isEnabled: true,
            createdAt: now,
            updatedAt: now
        )
    }

    public static func disabled(now: Date = Date()) -> AlarmEntity {
        AlarmEntity(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000005")!,
            label: "（無効）休日アラーム",
            scheduleKind: .recurringWeekly,
            timeOfDayHour: 8,
            timeOfDayMinute: 0,
            weekdayMaskRaw: WeekdayMask([.saturday]).rawValue,
            soundId: "gentle",
            isEnabled: false,
            createdAt: now,
            updatedAt: now
        )
    }

    public static func portfolio(now: Date = Date()) -> [AlarmEntity] {
        [
            morningWeekdays(now: now),
            weekendLateMorning(now: now),
            eveningOneShot(now: now),
            pomodoroCountdown(now: now),
            disabled(now: now)
        ]
    }
}

public extension AlarmSpec {
    static func sampleMorningWeekdays() -> AlarmSpec {
        AlarmSpec(entity: SampleAlarms.morningWeekdays())
    }
    static func sampleCountdownPomodoro() -> AlarmSpec {
        AlarmSpec(entity: SampleAlarms.pomodoroCountdown())
    }
}
