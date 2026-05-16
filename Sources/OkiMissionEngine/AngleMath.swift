import Foundation

public struct Point2D: Equatable, Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum AngleMath {
    public static func angleDegrees(at vertex: Point2D, from p1: Point2D, to p2: Point2D) -> Double {
        let v1x = p1.x - vertex.x
        let v1y = p1.y - vertex.y
        let v2x = p2.x - vertex.x
        let v2y = p2.y - vertex.y

        let dot = v1x * v2x + v1y * v2y
        let mag1 = (v1x * v1x + v1y * v1y).squareRoot()
        let mag2 = (v2x * v2x + v2y * v2y).squareRoot()

        guard mag1 > 0, mag2 > 0 else { return 0 }

        let cosTheta = max(-1.0, min(1.0, dot / (mag1 * mag2)))
        return acos(cosTheta) * 180 / .pi
    }
}
