import Foundation
import OkiMissionCore

public enum PushupPhase: String, Sendable, Equatable {
    case up
    case down
}

public enum RepEvent: Sendable, Equatable {
    case phaseChanged(PushupPhase)
    case repCompleted(count: Int, durationSeconds: Double)
    case repRejectedTooFast
    case lowConfidence
}

public struct PushupConfig: Sendable, Equatable {
    public var downAngleThreshold: Double
    public var upAngleThreshold: Double
    public var minRepDuration: TimeInterval
    public var minConfidence: Double

    public init(
        downAngleThreshold: Double = 90,
        upAngleThreshold: Double = 160,
        minRepDuration: TimeInterval = 0.8,
        minConfidence: Double = 0.4
    ) {
        self.downAngleThreshold = downAngleThreshold
        self.upAngleThreshold = upAngleThreshold
        self.minRepDuration = minRepDuration
        self.minConfidence = minConfidence
    }

    public static let `default` = PushupConfig()
}

public final class PushupRepCounter {
    public private(set) var phase: PushupPhase = .up
    public private(set) var repCount: Int = 0
    private var lastPhaseChangeAt: TimeInterval
    private let config: PushupConfig
    private let clock: AppClock

    public init(config: PushupConfig = .default, clock: AppClock = SystemClock()) {
        self.config = config
        self.clock = clock
        self.lastPhaseChangeAt = clock.uptime()
    }

    public func consume(elbowAngle: Double, leftConfidence: Double, rightConfidence: Double) -> RepEvent? {
        guard max(leftConfidence, rightConfidence) >= config.minConfidence else {
            return .lowConfidence
        }

        let now = clock.uptime()

        switch phase {
        case .up where elbowAngle <= config.downAngleThreshold:
            phase = .down
            lastPhaseChangeAt = now
            return .phaseChanged(.down)

        case .down where elbowAngle >= config.upAngleThreshold:
            let duration = now - lastPhaseChangeAt
            phase = .up
            lastPhaseChangeAt = now
            if duration >= config.minRepDuration {
                repCount += 1
                return .repCompleted(count: repCount, durationSeconds: duration)
            } else {
                return .repRejectedTooFast
            }

        default:
            return nil
        }
    }

    public func reset() {
        phase = .up
        repCount = 0
        lastPhaseChangeAt = clock.uptime()
    }
}
