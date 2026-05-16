import Testing
@testable import OkiMissionEngine

@Suite("PoseSmoother")
struct PoseSmootherTests {
    @Test("first value passes through unchanged")
    func firstValueIsRaw() {
        let smoother = PoseSmoother(alpha: 0.4)
        #expect(smoother.smooth(100) == 100)
    }

    @Test("subsequent values apply EMA")
    func emaApplied() {
        let smoother = PoseSmoother(alpha: 0.5)
        _ = smoother.smooth(100)
        let second = smoother.smooth(200)
        #expect(second == 150)
    }

    @Test("reset clears state")
    func resetClearsState() {
        let smoother = PoseSmoother(alpha: 0.5)
        _ = smoother.smooth(100)
        smoother.reset()
        #expect(smoother.smooth(50) == 50)
    }

    @Test("step response converges towards target")
    func convergence() {
        let smoother = PoseSmoother(alpha: 0.4)
        _ = smoother.smooth(0)
        var value: Double = 0
        for _ in 0..<20 {
            value = smoother.smooth(100)
        }
        #expect(abs(value - 100) < 0.1)
    }
}
