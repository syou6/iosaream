import Testing
import Foundation
@testable import OkiMissionCore

@Suite("StreakCalculator")
struct StreakCalculatorTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var components = DateComponents()
        components.year = y; components.month = m; components.day = d
        components.timeZone = TimeZone(identifier: "UTC")
        return calendar.date(from: components)!
    }

    @Test("first success starts streak at 1")
    func firstSuccess() {
        let next = StreakCalculator.registerSuccess(
            state: .empty,
            successDate: date(2026, 5, 16),
            calendar: calendar
        )
        #expect(next.currentStreak == 1)
        #expect(next.longestStreak == 1)
        #expect(next.lastSuccessDate == date(2026, 5, 16))
        #expect(next.currentStreakStartDate == date(2026, 5, 16))
    }

    @Test("consecutive day increments streak")
    func consecutiveDay() {
        let day1 = StreakCalculator.registerSuccess(
            state: .empty,
            successDate: date(2026, 5, 15),
            calendar: calendar
        )
        let day2 = StreakCalculator.registerSuccess(
            state: day1,
            successDate: date(2026, 5, 16),
            calendar: calendar
        )
        #expect(day2.currentStreak == 2)
        #expect(day2.longestStreak == 2)
    }

    @Test("skipping a day resets to 1")
    func skippedDay() {
        let day1 = StreakCalculator.registerSuccess(
            state: .empty,
            successDate: date(2026, 5, 14),
            calendar: calendar
        )
        let day3 = StreakCalculator.registerSuccess(
            state: day1,
            successDate: date(2026, 5, 16),
            calendar: calendar
        )
        #expect(day3.currentStreak == 1)
        #expect(day3.longestStreak == 1)
        #expect(day3.currentStreakStartDate == date(2026, 5, 16))
    }

    @Test("same day succeeds idempotently")
    func sameDay() {
        let day1 = StreakCalculator.registerSuccess(
            state: .empty,
            successDate: date(2026, 5, 16),
            calendar: calendar
        )
        let same = StreakCalculator.registerSuccess(
            state: day1,
            successDate: date(2026, 5, 16),
            calendar: calendar
        )
        #expect(same == day1)
    }

    @Test("longestStreak preserved when broken")
    func longestPreserved() {
        var state = StreakState.empty
        for day in 10...14 {
            state = StreakCalculator.registerSuccess(
                state: state,
                successDate: date(2026, 5, day),
                calendar: calendar
            )
        }
        #expect(state.currentStreak == 5)
        #expect(state.longestStreak == 5)

        let resumed = StreakCalculator.registerSuccess(
            state: state,
            successDate: date(2026, 5, 18),
            calendar: calendar
        )
        #expect(resumed.currentStreak == 1)
        #expect(resumed.longestStreak == 5)
    }

    @Test("breakIfStale clears streak when older than yesterday")
    func breakStale() {
        var state = StreakCalculator.registerSuccess(
            state: .empty,
            successDate: date(2026, 5, 10),
            calendar: calendar
        )
        state = StreakCalculator.breakIfStale(
            state: state,
            reference: date(2026, 5, 16),
            calendar: calendar
        )
        #expect(state.currentStreak == 0)
        #expect(state.currentStreakStartDate == nil)
        #expect(state.longestStreak == 1)
        #expect(state.lastSuccessDate == date(2026, 5, 10))
    }

    @Test("breakIfStale leaves yesterday's success intact")
    func breakLeavesYesterday() {
        let state = StreakCalculator.registerSuccess(
            state: .empty,
            successDate: date(2026, 5, 15),
            calendar: calendar
        )
        let checked = StreakCalculator.breakIfStale(
            state: state,
            reference: date(2026, 5, 16),
            calendar: calendar
        )
        #expect(checked == state)
    }

    @Test("breakIfStale is no-op when empty")
    func breakEmpty() {
        let result = StreakCalculator.breakIfStale(
            state: .empty,
            reference: date(2026, 5, 16),
            calendar: calendar
        )
        #expect(result == .empty)
    }
}
