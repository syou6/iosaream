import Foundation

public enum JointKey: String, Sendable, Codable, CaseIterable, Hashable {
    case nose
    case leftEye, rightEye
    case leftEar, rightEar
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
}

public struct JointPoint: Sendable, Equatable, Codable, Hashable {
    public let location: UnitPoint
    public let confidence: Double

    public init(location: UnitPoint, confidence: Double) {
        self.location = location
        self.confidence = confidence
    }
}

public struct PoseObservation: Sendable, Equatable, Codable {
    public let joints: [JointKey: JointPoint]
    public let frameId: UUID

    public init(joints: [JointKey: JointPoint], frameId: UUID) {
        self.joints = joints
        self.frameId = frameId
    }

    public func point(_ key: JointKey, minConfidence: Double = 0.4) -> UnitPoint? {
        guard let joint = joints[key], joint.confidence >= minConfidence else { return nil }
        return joint.location
    }
}

public protocol PoseDetecting: Sendable {
    func detect(_ frame: CameraFrame) async throws -> PoseObservation?
}

public actor ScriptedPoseDetector: PoseDetecting {
    private var script: [PoseObservation?]
    private var index: Int = 0

    public init(script: [PoseObservation?]) {
        self.script = script
    }

    public func detect(_ frame: CameraFrame) async throws -> PoseObservation? {
        guard !script.isEmpty else { return nil }
        let observation = script[index % script.count]
        index += 1
        return observation
    }
}
