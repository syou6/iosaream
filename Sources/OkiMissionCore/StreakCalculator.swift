import Foundation

public struct StreakState: Equatable, Sendable, Codable {
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastSuccessDate: Date?
    public var currentStreakStartDate: Date?

    public init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastSuccessDate: Date? = nil,
        currentStreakStartDate: Date? = nil
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastSuccessDate = lastSuccessDate
        self.currentStreakStartDate = currentStreakStartDate
    }

    public static let empty = StreakState()
}

public enum StreakCalculator {
    public static func registerSuccess(
        state: StreakState,
        successDate: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> StreakState {
        let today = calendar.startOfDay(for: successDate)
        var next = state

        if let last = state.lastSuccessDate {
            let lastDay = calendar.startOfDay(for: last)
            if lastDay == today {
                return state
            }
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if lastDay == yesterday {
                next.currentStreak += 1
            } else {
                next.currentStreak = 1
                next.currentStreakStartDate = today
            }
        } else {
            next.currentStreak = 1
            next.currentStreakStartDate = today
        }

        next.lastSuccessDate = today
        next.longestStreak = max(next.longestStreak, next.currentStreak)
        return next
    }

    public static func breakIfStale(
        state: StreakState,
        reference: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> StreakState {
        guard let last = state.lastSuccessDate else { return state }
        let lastDay = calendar.startOfDay(for: last)
        let today = calendar.startOfDay(for: reference)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        guard lastDay < yesterday else { return state }
        var next = state
        next.currentStreak = 0
        next.currentStreakStartDate = nil
        return next
    }
}
