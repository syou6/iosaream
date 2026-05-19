import Foundation

public struct ObjectObservation: Sendable, Equatable, Codable {
    public let className: String
    public let confidence: Double
    public let boundingBox: UnitRect
    public let frameId: UUID

    public init(className: String, confidence: Double, boundingBox: UnitRect, frameId: UUID) {
        self.className = className
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.frameId = frameId
    }
}

public protocol ObjectDetecting: Sendable {
    func detect(_ frame: CameraFrame, allowedClasses: Set<String>?) async throws -> [ObjectObservation]
}

public actor ScriptedObjectDetector: ObjectDetecting {
    private var script: [[ObjectObservation]]
    private var index: Int = 0

    public init(script: [[ObjectObservation]]) {
        self.script = script
    }

    public func detect(_ frame: CameraFrame, allowedClasses: Set<String>?) async throws -> [ObjectObservation] {
        guard !script.isEmpty else { return [] }
        let observations = script[index % script.count]
        index += 1
        if let allowed = allowedClasses {
            return observations.filter { allowed.contains($0.className) }
        }
        return observations
    }
}
