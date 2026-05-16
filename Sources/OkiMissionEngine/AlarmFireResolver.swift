import Foundation
import OkiMissionCore

public enum AlarmFireResolver {
    public static func nextFireDate(
        for spec: AlarmSpec,
        after reference: Date,
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current
    ) -> Date? {
        guard spec.isEnabled else { return nil }
        switch spec.scheduleKind {
        case .oneShot:
            guard let fire = spec.fireDate else { return nil }
            return fire > reference ? fire : nil

        case .recurringWeekly:
            guard let time = spec.timeOfDay, !spec.weekdayMask.isEmpty else { return nil }
            return nextWeeklyOccurrence(
                time: time,
                weekdays: spec.weekdayMask,
                after: reference,
                calendar: calendar,
                timeZone: timeZone
            )

        case .countdown:
            guard let seconds = spec.countdownSeconds, seconds > 0 else { return nil }
            return reference.addingTimeInterval(TimeInterval(seconds))
        }
    }

    public static func upcomingFireDates(
        for spec: AlarmSpec,
        after reference: Date,
        limit: Int = 7,
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current
    ) -> [Date] {
        guard limit > 0 else { return [] }
        switch spec.scheduleKind {
        case .oneShot, .countdown:
            return nextFireDate(for: spec, after: reference, calendar: calendar, timeZone: timeZone).map { [$0] } ?? []

        case .recurringWeekly:
            var results: [Date] = []
            var cursor = reference
            while results.count < limit {
                guard let next = nextFireDate(
                    for: spec,
                    after: cursor,
                    calendar: calendar,
                    timeZone: timeZone
                ) else { break }
                results.append(next)
                cursor = next
            }
            return results
        }
    }

    private static func nextWeeklyOccurrence(
        time: TimeOfDay,
        weekdays: WeekdayMask,
        after reference: Date,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Date? {
        var workingCalendar = calendar
        workingCalendar.timeZone = timeZone

        for dayOffset in 0..<14 {
            guard let dayDate = workingCalendar.date(byAdding: .day, value: dayOffset, to: reference) else { continue }
            let weekdayValue = workingCalendar.component(.weekday, from: dayDate)
            guard let weekday = Weekday(rawValue: weekdayValue) else { continue }
            guard weekdays.contains(weekday) else { continue }
            var components = workingCalendar.dateComponents([.year, .month, .day], from: dayDate)
            components.hour = time.hour
            components.minute = time.minute
            components.second = 0
            guard let candidate = workingCalendar.date(from: components) else { continue }
            if candidate > reference {
                return candidate
            }
        }
        return nil
    }
}
