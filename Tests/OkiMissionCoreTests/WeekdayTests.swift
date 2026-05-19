import Testing
@testable import OkiMissionCore

@Suite("WeekdayMask")
struct WeekdayMaskTests {
    @Test("empty has no weekdays")
    func empty() {
        #expect(WeekdayMask.empty.isEmpty)
        #expect(WeekdayMask.empty.decoded() == [])
    }

    @Test("weekdays preset contains Mon..Fri only")
    func weekdaysPreset() {
        let mask = WeekdayMask.weekdays
        #expect(mask.contains(.monday))
        #expect(mask.contains(.friday))
        #expect(!mask.contains(.saturday))
        #expect(!mask.contains(.sunday))
    }

    @Test("weekends preset contains Sat and Sun only")
    func weekendsPreset() {
        let mask = WeekdayMask.weekends
        #expect(mask.contains(.saturday))
        #expect(mask.contains(.sunday))
        #expect(!mask.contains(.monday))
    }

    @Test("init with sequence builds correct mask")
    func initFromSequence() {
        let mask = WeekdayMask([.tuesday, .thursday])
        #expect(mask.decoded() == [.tuesday, .thursday])
    }

    @Test("all preset contains every weekday")
    func allPreset() {
        let mask = WeekdayMask.all
        for day in Weekday.allCases {
            #expect(mask.contains(day))
        }
    }

    @Test("rawValue masks to 7 bits")
    func rawValueMask() {
        let mask = WeekdayMask(rawValue: 0xFF)
        #expect(mask.rawValue == 0x7F)
    }
}
