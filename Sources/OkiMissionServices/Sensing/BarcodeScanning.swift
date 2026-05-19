import Foundation

public struct BarcodeObservation: Sendable, Equatable, Codable {
    public let payload: String
    public let symbology: String
    public let boundingBox: UnitRect
    public let frameId: UUID

    public init(payload: String, symbology: String, boundingBox: UnitRect, frameId: UUID) {
        self.payload = payload
        self.symbology = symbology
        self.boundingBox = boundingBox
        self.frameId = frameId
    }
}

public protocol BarcodeScanning: Sendable {
    func scan(_ frame: CameraFrame) async throws -> [BarcodeObservation]
}

public actor ScriptedBarcodeScanner: BarcodeScanning {
    private var script: [[BarcodeObservation]]
    private var index: Int = 0

    public init(script: [[BarcodeObservation]]) {
        self.script = script
    }

    public func scan(_ frame: CameraFrame) async throws -> [BarcodeObservation] {
        guard !script.isEmpty else { return [] }
        defer { index += 1 }
        return script[index % script.count]
    }
}
