import Foundation
import OkiMissionCore

public struct AntiCheatContext: Sendable {
    public var backgroundEvents: [Date]
    public var clockReadings: [ClockReading]
    public var screenshotEvents: [Date]
    public var frameGapsSeconds: [TimeInterval]
    public var sessionStart: Date
    public var sessionStartUptime: TimeInterval

    public init(
        sessionStart: Date,
        sessionStartUptime: TimeInterval,
        backgroundEvents: [Date] = [],
        clockReadings: [ClockReading] = [],
        screenshotEvents: [Date] = [],
        frameGapsSeconds: [TimeInterval] = []
    ) {
        self.sessionStart = sessionStart
        self.sessionStartUptime = sessionStartUptime
        self.backgroundEvents = backgroundEvents
        self.clockReadings = clockReadings
        self.screenshotEvents = screenshotEvents
        self.frameGapsSeconds = frameGapsSeconds
    }

    public struct ClockReading: Sendable, Equatable {
        public var uptime: TimeInterval
        public var wallClock: Date

        public init(uptime: TimeInterval, wallClock: Date) {
            self.uptime = uptime
            self.wallClock = wallClock
        }
    }
}

public struct AntiCheatPolicy: Sendable {
    public var failingScore: Int
    public var clockDriftToleranceSeconds: Double
    public var bigFrameGapSeconds: TimeInterval
    public var bigFrameGapCount: Int
    public var minimumDurationByKind: [MissionKind: TimeInterval]

    public init(
        failingScore: Int = 5,
        clockDriftToleranceSeconds: Double = 5,
        bigFrameGapSeconds: TimeInterval = 1.0,
        bigFrameGapCount: Int = 3,
        minimumDurationByKind: [MissionKind: TimeInterval] = [
            .pushup: 10,
            .squat: 10,
            .math: 8,
            .shake: 5,
            .objectHunt: 8,
            .barcode: 4
        ]
    ) {
        self.failingScore = failingScore
        self.clockDriftToleranceSeconds = clockDriftToleranceSeconds
        self.bigFrameGapSeconds = bigFrameGapSeconds
        self.bigFrameGapCount = bigFrameGapCount
        self.minimumDurationByKind = minimumDurationByKind
    }

    public static let `default` = AntiCheatPolicy()
}

public struct AntiCheatEvaluator: Sendable {
    public let policy: AntiCheatPolicy

    public init(policy: AntiCheatPolicy = .default) {
        self.policy = policy
    }

    public func evaluate(
        context: AntiCheatContext,
        kind: MissionKind,
        durationSeconds: TimeInterval
    ) -> AntiCheatVerdict {
        var score = 0
        var signals: [AntiCheatSignal] = []

        let bgCount = context.backgroundEvents.count
        if bgCount > 0 {
            score += 2 * bgCount
            signals.append(.backgrounded(count: bgCount))
        }

        if let first = context.clockReadings.first,
           let last = context.clockReadings.last,
           first != last {
            let wallDelta = last.wallClock.timeIntervalSince(first.wallClock)
            let uptimeDelta = last.uptime - first.uptime
            let diff = wallDelta - uptimeDelta
            if abs(diff) > policy.clockDriftToleranceSeconds {
                score += 5
                signals.append(.clockTampered(diffSeconds: diff))
            }
        }

        if !context.screenshotEvents.isEmpty {
            score += context.screenshotEvents.count
            signals.append(.screenshotsTaken(count: context.screenshotEvents.count))
        }

        let bigGaps = context.frameGapsSeconds.filter { $0 > policy.bigFrameGapSeconds }
        if bigGaps.count >= policy.bigFrameGapCount {
            score += 3
            signals.append(.frameGaps(count: bigGaps.count))
        }

        if let minDuration = policy.minimumDurationByKind[kind], durationSeconds < minDuration {
            score += 4
            signals.append(.tooFast(durationSeconds: durationSeconds))
        }

        return score >= policy.failingScore ? .cheated(signals) : .clean
    }
}
