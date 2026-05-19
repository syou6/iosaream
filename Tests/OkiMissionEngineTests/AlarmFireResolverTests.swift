import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionEngine

@Suite("AlarmFireResolver")
struct AlarmFireResolverTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return cal
    }()

    private let tz = TimeZone(identifier: "Asia/Tokyo")!

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        var components = DateComponents()
        components.year = y; components.month = m; components.day = d
        components.hour = h; components.minute = min
        components.timeZone = tz
        return calendar.date(from: components)!
    }

    @Test("oneShot in the future returns the fire date")
    func oneShotFuture() {
        let target = date(2026, 5, 17, 7, 0)
        let spec = AlarmSpec(
            label: "Tomorrow",
            scheduleKind: .oneShot,
            fireDate: target,
            soundId: "default"
        )
        let next = AlarmFireResolver.nextFireDate(
            for: spec,
            after: date(2026, 5, 16, 23, 0),
            calendar: calendar,
            timeZone: tz
        )
        #expect(next == target)
    }

    @Test("oneShot in the past returns nil")
    func oneShotPast() {
        let spec = AlarmSpec(
            label: "Yesterday",
            scheduleKind: .oneShot,
            fireDate: date(2026, 5, 15, 7, 0),
            soundId: "default"
        )
        let next = AlarmFireResolver.nextFireDate(
            for: spec,
            after: date(2026, 5, 16, 23, 0),
            calendar: calendar,
            timeZone: tz
        )
        #expect(next == nil)
    }

    @Test("disabled alarm returns nil")
    func disabledReturnsNil() {
        let spec = AlarmSpec(
            label: "Off",
            scheduleKind: .oneShot,
            fireDate: date(2026, 5, 17, 7, 0),
            soundId: "default",
            isEnabled: false
        )
        let next = AlarmFireResolver.nextFireDate(
            for: spec,
            after: date(2026, 5, 16),
            calendar: calendar,
            timeZone: tz
        )
        #expect(next == nil)
    }

    @Test("countdown adds seconds to reference")
    func countdownAddsSeconds() {
        let spec = AlarmSpec(
            label: "Timer",
            scheduleKind: .countdown,
            countdownSeconds: 300,
            soundId: "default"
        )
        let reference = date(2026, 5, 16, 10, 0)
        let next = AlarmFireResolver.nextFireDate(
            for: spec,
            after: reference,
            calendar: calendar,
            timeZone: tz
        )
        #expect(next == reference.addingTimeInterval(300))
    }

    @Test("weekly returns next matching weekday")
    func weeklyNextWeekday() {
        let spec = AlarmSpec(
            label: "Weekday",
            scheduleKind: .recurringWeekly,
            timeOfDay: TimeOfDay(hour: 7, minute: 0),
            weekdayMask: WeekdayMask([.monday]),
            soundId: "default"
        )
        let saturday = date(2026, 5, 16, 23, 0)
        let next = AlarmFireResolver.nextFireDate(
            for: spec,
            after: saturday,
            calendar: calendar,
            timeZone: tz
        )
        #expect(next == date(2026, 5, 18, 7, 0))
    }

    @Test("weekly skips to next week if today already passed")
    func weeklySkipsToday() {
        let spec = AlarmSpec(
            label: "Saturday",
            scheduleKind: .recurringWeekly,
            timeOfDay: TimeOfDay(hour: 7, minute: 0),
            weekdayMask: WeekdayMask([.saturday]),
            soundId: "default"
        )
        let saturdayLate = date(2026, 5, 16, 23, 0)
        let next = AlarmFireResolver.nextFireDate(
            for: spec,
            after: saturdayLate,
            calendar: calendar,
            timeZone: tz
        )
        #expect(next == date(2026, 5, 23, 7, 0))
    }

    @Test("weekly with same weekday earlier today returns later today")
    func weeklySameDayLater() {
        let spec = AlarmSpec(
            label: "Saturday morning",
            scheduleKind: .recurringWeekly,
            timeOfDay: TimeOfDay(hour: 9, minute: 0),
            weekdayMask: WeekdayMask([.saturday]),
            soundId: "default"
        )
        let saturdayEarly = date(2026, 5, 16, 6, 0)
        let next = AlarmFireResolver.nextFireDate(
            for: spec,
            after: saturdayEarly,
            calendar: calendar,
            timeZone: tz
        )
        #expect(next == date(2026, 5, 16, 9, 0))
    }

    @Test("upcoming weekly returns ascending dates")
    func upcomingAscending() {
        let spec = AlarmSpec(
            label: "Weekdays",
            scheduleKind: .recurringWeekly,
            timeOfDay: TimeOfDay(hour: 7, minute: 30),
            weekdayMask: .weekdays,
            soundId: "default"
        )
        let saturday = date(2026, 5, 16, 12, 0)
        let upcoming = AlarmFireResolver.upcomingFireDates(
            for: spec,
            after: saturday,
            limit: 3,
            calendar: calendar,
            timeZone: tz
        )
        #expect(upcoming.count == 3)
        let expected = [
            date(2026, 5, 18, 7, 30),
            date(2026, 5, 19, 7, 30),
            date(2026, 5, 20, 7, 30)
        ]
        #expect(upcoming == expected)
    }
}
