import Foundation

public struct AccelerationSample: Sendable, Equatable, Codable, Hashable {
    public let x: Double
    public let y: Double
    public let z: Double
    public let timestamp: TimeInterval

    public init(x: Double, y: Double, z: Double, timestamp: TimeInterval) {
        self.x = x; self.y = y; self.z = z; self.timestamp = timestamp
    }

    public var magnitude: Double {
        (x * x + y * y + z * z).squareRoot()
    }
}
