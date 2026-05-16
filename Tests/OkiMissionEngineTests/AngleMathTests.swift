import Testing
import Foundation
@testable import OkiMissionEngine

@Suite("AngleMath")
struct AngleMathTests {
    @Test("perpendicular vectors yield 90 degrees")
    func perpendicular() {
        let angle = AngleMath.angleDegrees(
            at: Point2D(x: 0, y: 0),
            from: Point2D(x: 1, y: 0),
            to: Point2D(x: 0, y: 1)
        )
        #expect(abs(angle - 90) < 1e-6)
    }

    @Test("collinear opposite vectors yield 180 degrees")
    func opposite() {
        let angle = AngleMath.angleDegrees(
            at: Point2D(x: 0, y: 0),
            from: Point2D(x: 1, y: 0),
            to: Point2D(x: -1, y: 0)
        )
        #expect(abs(angle - 180) < 1e-6)
    }

    @Test("collinear same direction yields 0 degrees")
    func sameDirection() {
        let angle = AngleMath.angleDegrees(
            at: Point2D(x: 0, y: 0),
            from: Point2D(x: 1, y: 0),
            to: Point2D(x: 2, y: 0)
        )
        #expect(abs(angle) < 1e-6)
    }

    @Test("zero-length vector returns 0")
    func zeroVector() {
        let angle = AngleMath.angleDegrees(
            at: Point2D(x: 0, y: 0),
            from: Point2D(x: 0, y: 0),
            to: Point2D(x: 1, y: 0)
        )
        #expect(angle == 0)
    }
}
