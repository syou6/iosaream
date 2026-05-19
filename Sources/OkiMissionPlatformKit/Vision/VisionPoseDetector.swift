import Foundation
import OkiMissionServices

#if canImport(Vision) && canImport(CoreVideo)
import Vision
import CoreVideo

public actor VisionPoseDetector: PoseDetecting {
    public typealias PixelBufferProvider = @Sendable (CameraFrame) async -> CVPixelBuffer?

    private let provider: PixelBufferProvider
    private let request: VNDetectHumanBodyPoseRequest

    public init(provider: @escaping PixelBufferProvider) {
        self.provider = provider
        self.request = VNDetectHumanBodyPoseRequest()
    }

    public func detect(_ frame: CameraFrame) async throws -> PoseObservation? {
        guard let pixelBuffer = await provider(frame) else { return nil }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first as? VNHumanBodyPoseObservation else {
            return nil
        }
        var joints: [JointKey: JointPoint] = [:]
        let mapping: [(VNHumanBodyPoseObservation.JointName, JointKey)] = [
            (.nose, .nose),
            (.leftEye, .leftEye), (.rightEye, .rightEye),
            (.leftEar, .leftEar), (.rightEar, .rightEar),
            (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
            (.leftElbow, .leftElbow), (.rightElbow, .rightElbow),
            (.leftWrist, .leftWrist), (.rightWrist, .rightWrist),
            (.leftHip, .leftHip), (.rightHip, .rightHip),
            (.leftKnee, .leftKnee), (.rightKnee, .rightKnee),
            (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle)
        ]
        for (visionName, key) in mapping {
            if let point = try? observation.recognizedPoint(visionName) {
                joints[key] = JointPoint(
                    location: UnitPoint(x: Double(point.location.x), y: Double(point.location.y)),
                    confidence: Double(point.confidence)
                )
            }
        }
        return PoseObservation(joints: joints, frameId: frame.identifier)
    }
}
#endif
