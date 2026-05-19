import Foundation
import OkiMissionCore

public final class BarcodeMissionEngine {
    public let targetCount: Int
    public private(set) var scannedPayloads: [String] = []
    private var scannedSet: Set<String> = []

    public init(params: BarcodeParams) {
        self.targetCount = max(1, params.targetCount)
    }

    @discardableResult
    public func consume(payload: String) -> Bool {
        guard !scannedSet.contains(payload) else { return false }
        scannedSet.insert(payload)
        scannedPayloads.append(payload)
        return true
    }

    public var isComplete: Bool { scannedPayloads.count >= targetCount }
    public var progress: Double {
        Double(scannedPayloads.count) / Double(targetCount)
    }

    public func reset() {
        scannedPayloads.removeAll()
        scannedSet.removeAll()
    }
}
