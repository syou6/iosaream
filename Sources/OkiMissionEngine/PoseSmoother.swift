import Foundation

public final class PoseSmoother {
    private var emaValue: Double?
    private let alpha: Double

    public init(alpha: Double = 0.4) {
        precondition((0...1).contains(alpha), "alpha must be in [0, 1]")
        self.alpha = alpha
    }

    public func smooth(_ raw: Double) -> Double {
        if let prev = emaValue {
            let next = alpha * raw + (1 - alpha) * prev
            emaValue = next
            return next
        } else {
            emaValue = raw
            return raw
        }
    }

    public func reset() {
        emaValue = nil
    }

    public var current: Double? { emaValue }
}
