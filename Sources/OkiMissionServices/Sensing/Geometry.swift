import Foundation

public struct UnitRect: Sendable, Equatable, Hashable, Codable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let zero = UnitRect(x: 0, y: 0, width: 0, height: 0)
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var area: Double { max(0, width) * max(0, height) }
}

public struct UnitPoint: Sendable, Equatable, Hashable, Codable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x; self.y = y
    }
}
