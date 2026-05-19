import Foundation

public enum Weekday: Int, Codable, CaseIterable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    public var bitFlag: Int {
        1 << (rawValue - 1)
    }
}

public struct WeekdayMask: Equatable, Hashable, Sendable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue & 0x7F
    }

    public init(_ weekdays: some Sequence<Weekday>) {
        self.rawValue = weekdays.reduce(0) { $0 | $1.bitFlag }
    }

    public static let empty = WeekdayMask(rawValue: 0)
    public static let weekdays = WeekdayMask([.monday, .tuesday, .wednesday, .thursday, .friday])
    public static let weekends = WeekdayMask([.saturday, .sunday])
    public static let all = WeekdayMask(Weekday.allCases)

    public func contains(_ weekday: Weekday) -> Bool {
        (rawValue & weekday.bitFlag) != 0
    }

    public func decoded() -> [Weekday] {
        Weekday.allCases.filter { contains($0) }
    }

    public var isEmpty: Bool { rawValue == 0 }
}
