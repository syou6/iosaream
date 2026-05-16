import Testing
import Foundation
@testable import OkiMissionCore

@Suite("AlarmSpec validation")
struct AlarmSpecTests {
    @Test("oneShot requires fireDate")
    func oneShotMissingDateFails() {
        let spec = AlarmSpec(
            label: "Morning",
            scheduleKind: .oneShot,
            soundId: "default"
        )
        #expect(throws: DomainError.invalidAlarmConfig) {
            try spec.validate()
        }
    }

    @Test("oneShot with fireDate passes")
    func oneShotWithDatePasses() {
        let spec = AlarmSpec(
            label: "Morning",
            scheduleKind: .oneShot,
            fireDate: Date(timeIntervalSinceNow: 60),
            soundId: "default"
        )
        #expect(throws: Never.self) {
            try spec.validate()
        }
    }

    @Test("recurringWeekly requires timeOfDay and non-empty mask")
    func recurringRequiresFields() {
        let noTime = AlarmSpec(
            label: "Weekday",
            scheduleKind: .recurringWeekly,
            weekdayMask: .weekdays,
            soundId: "default"
        )
        #expect(throws: DomainError.invalidAlarmConfig) {
            try noTime.validate()
        }

        let noDays = AlarmSpec(
            label: "Weekday",
            scheduleKind: .recurringWeekly,
            timeOfDay: TimeOfDay(hour: 7, minute: 0),
            weekdayMask: .empty,
            soundId: "default"
        )
        #expect(throws: DomainError.invalidAlarmConfig) {
            try noDays.validate()
        }
    }

    @Test("countdown requires positive seconds")
    func countdownRequiresPositive() {
        let zero = AlarmSpec(
            label: "Timer",
            scheduleKind: .countdown,
            countdownSeconds: 0,
            soundId: "default"
        )
        #expect(throws: DomainError.invalidAlarmConfig) {
            try zero.validate()
        }
    }

    @Test("countdown with positive seconds passes")
    func countdownPositiveOK() {
        let spec = AlarmSpec(
            label: "Timer",
            scheduleKind: .countdown,
            countdownSeconds: 300,
            soundId: "default"
        )
        #expect(throws: Never.self) {
            try spec.validate()
        }
    }
}
