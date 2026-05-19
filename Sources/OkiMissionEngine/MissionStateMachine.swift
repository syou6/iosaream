import Foundation
import OkiMissionCore

public struct MissionStateMachine: Sendable, Equatable {
    public private(set) var state: MissionState
    public private(set) var framingSustainedFrames: Int
    public let framingThreshold: Double
    public let framingFramesRequired: Int

    public init(
        framingThreshold: Double = 0.5,
        framingFramesRequired: Int = 8
    ) {
        self.state = .idle
        self.framingSustainedFrames = 0
        self.framingThreshold = framingThreshold
        self.framingFramesRequired = framingFramesRequired
    }

    @discardableResult
    public mutating func start() -> MissionState {
        guard case .idle = state else { return state }
        state = .checkingCapabilities
        return state
    }

    @discardableResult
    public mutating func capabilityResolved(_ capability: Capability, authorized: Bool) -> MissionState {
        guard case .checkingCapabilities = state else { return state }
        if authorized {
            state = .framing(progress: 0)
            framingSustainedFrames = 0
        } else {
            state = .awaitingPermission(capability)
        }
        return state
    }

    @discardableResult
    public mutating func permissionGranted(_ capability: Capability) -> MissionState {
        guard case .awaitingPermission(let pending) = state, pending == capability else { return state }
        state = .framing(progress: 0)
        framingSustainedFrames = 0
        return state
    }

    @discardableResult
    public mutating func updateFraming(progress: Double) -> MissionState {
        guard case .framing = state else { return state }
        let clamped = max(0, min(1, progress))
        if clamped >= framingThreshold {
            framingSustainedFrames += 1
            if framingSustainedFrames >= framingFramesRequired {
                state = .running(progress: 0)
                return state
            }
        } else {
            framingSustainedFrames = 0
        }
        state = .framing(progress: clamped)
        return state
    }

    @discardableResult
    public mutating func updateProgress(_ progress: Double) -> MissionState {
        guard case .running = state else { return state }
        let clamped = max(0, min(1, progress))
        state = .running(progress: clamped)
        return state
    }

    @discardableResult
    public mutating func pause(reason: PauseReason) -> MissionState {
        switch state {
        case .running, .framing:
            state = .paused(reason)
        default:
            break
        }
        return state
    }

    @discardableResult
    public mutating func resume() -> MissionState {
        guard case .paused = state else { return state }
        state = .running(progress: 0)
        return state
    }

    @discardableResult
    public mutating func conditionsMet() -> MissionState {
        guard case .running = state else { return state }
        state = .verifying
        return state
    }

    @discardableResult
    public mutating func verified(clean: Bool, signals: [AntiCheatSignal] = []) -> MissionState {
        guard case .verifying = state else { return state }
        state = clean ? .completed : .cheated(signals)
        return state
    }

    @discardableResult
    public mutating func fail(_ reason: MissionFailureReason) -> MissionState {
        guard !state.isTerminal else { return state }
        state = .failed(reason)
        return state
    }

    @discardableResult
    public mutating func cancel() -> MissionState {
        guard !state.isTerminal else { return state }
        state = .cancelled
        return state
    }
}
