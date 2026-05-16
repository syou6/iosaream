import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionEngine

@Suite("MissionStateMachine")
struct MissionStateMachineTests {
    @Test("starts in idle state")
    func startsIdle() {
        let machine = MissionStateMachine()
        #expect(machine.state == .idle)
    }

    @Test("start moves to checkingCapabilities")
    func startsChecks() {
        var machine = MissionStateMachine()
        machine.start()
        #expect(machine.state == .checkingCapabilities)
    }

    @Test("authorized capability moves to framing")
    func authorizedMovesToFraming() {
        var machine = MissionStateMachine()
        machine.start()
        machine.capabilityResolved(.camera, authorized: true)
        if case .framing(let progress) = machine.state {
            #expect(progress == 0)
        } else {
            Issue.record("expected framing state, got \(machine.state)")
        }
    }

    @Test("denied capability moves to awaitingPermission")
    func deniedMovesToAwaiting() {
        var machine = MissionStateMachine()
        machine.start()
        machine.capabilityResolved(.camera, authorized: false)
        #expect(machine.state == .awaitingPermission(.camera))
    }

    @Test("permissionGranted advances awaitingPermission to framing")
    func permissionGranted() {
        var machine = MissionStateMachine()
        machine.start()
        machine.capabilityResolved(.camera, authorized: false)
        machine.permissionGranted(.camera)
        if case .framing = machine.state {} else {
            Issue.record("expected framing, got \(machine.state)")
        }
    }

    @Test("framing transitions to running after sustained progress")
    func framingThenRunning() {
        var machine = MissionStateMachine(framingThreshold: 0.5, framingFramesRequired: 3)
        machine.start()
        machine.capabilityResolved(.camera, authorized: true)
        machine.updateFraming(progress: 0.6)
        machine.updateFraming(progress: 0.7)
        let final = machine.updateFraming(progress: 0.8)
        if case .running = final {} else {
            Issue.record("expected running, got \(final)")
        }
    }

    @Test("framing resets streak when progress drops below threshold")
    func framingDropsResets() {
        var machine = MissionStateMachine(framingThreshold: 0.5, framingFramesRequired: 3)
        machine.start()
        machine.capabilityResolved(.camera, authorized: true)
        machine.updateFraming(progress: 0.6)
        machine.updateFraming(progress: 0.7)
        machine.updateFraming(progress: 0.2)
        machine.updateFraming(progress: 0.6)
        machine.updateFraming(progress: 0.6)
        let state = machine.state
        if case .framing = state {} else {
            Issue.record("expected framing, got \(state)")
        }
    }

    @Test("running progress is clamped to 0...1")
    func progressClamped() {
        var machine = MissionStateMachine(framingThreshold: 0.5, framingFramesRequired: 1)
        machine.start()
        machine.capabilityResolved(.camera, authorized: true)
        machine.updateFraming(progress: 0.9)
        machine.updateProgress(1.5)
        if case .running(let p) = machine.state {
            #expect(p == 1.0)
        } else {
            Issue.record("expected running")
        }
    }

    @Test("pause and resume cycle keeps mission alive")
    func pauseResume() {
        var machine = MissionStateMachine(framingThreshold: 0.5, framingFramesRequired: 1)
        machine.start()
        machine.capabilityResolved(.camera, authorized: true)
        machine.updateFraming(progress: 0.9)
        machine.pause(reason: .appBackgrounded)
        #expect(machine.state == .paused(.appBackgrounded))
        machine.resume()
        if case .running = machine.state {} else {
            Issue.record("expected running, got \(machine.state)")
        }
    }

    @Test("conditionsMet moves running to verifying")
    func conditionsMet() {
        var machine = MissionStateMachine(framingThreshold: 0.5, framingFramesRequired: 1)
        machine.start()
        machine.capabilityResolved(.camera, authorized: true)
        machine.updateFraming(progress: 0.9)
        machine.conditionsMet()
        #expect(machine.state == .verifying)
    }

    @Test("verified clean moves to completed")
    func verifiedClean() {
        var machine = MissionStateMachine(framingThreshold: 0.5, framingFramesRequired: 1)
        machine.start()
        machine.capabilityResolved(.camera, authorized: true)
        machine.updateFraming(progress: 0.9)
        machine.conditionsMet()
        machine.verified(clean: true)
        #expect(machine.state == .completed)
    }

    @Test("verified with signals moves to cheated")
    func verifiedCheated() {
        var machine = MissionStateMachine(framingThreshold: 0.5, framingFramesRequired: 1)
        machine.start()
        machine.capabilityResolved(.camera, authorized: true)
        machine.updateFraming(progress: 0.9)
        machine.conditionsMet()
        let signal = AntiCheatSignal.backgrounded(count: 2)
        machine.verified(clean: false, signals: [signal])
        #expect(machine.state == .cheated([signal]))
    }

    @Test("fail transitions running into failed")
    func failsRunning() {
        var machine = MissionStateMachine(framingThreshold: 0.5, framingFramesRequired: 1)
        machine.start()
        machine.capabilityResolved(.camera, authorized: true)
        machine.updateFraming(progress: 0.9)
        machine.fail(.timeout)
        #expect(machine.state == .failed(.timeout))
    }

    @Test("cancel any non-terminal state moves to cancelled")
    func cancelFromActive() {
        var machine = MissionStateMachine()
        machine.start()
        machine.cancel()
        #expect(machine.state == .cancelled)
    }

    @Test("terminal state is immutable")
    func terminalImmutable() {
        var machine = MissionStateMachine(framingThreshold: 0.5, framingFramesRequired: 1)
        machine.start()
        machine.capabilityResolved(.camera, authorized: true)
        machine.updateFraming(progress: 0.9)
        machine.fail(.timeout)
        machine.cancel()
        #expect(machine.state == .failed(.timeout))
    }
}
