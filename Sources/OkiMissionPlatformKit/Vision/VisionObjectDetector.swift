import Foundation
import OkiMissionServices

#if canImport(Vision) && canImport(CoreML) && canImport(CoreVideo)
import Vision
import CoreML
import CoreVideo

public actor VisionObjectDetector: ObjectDetecting {
    public typealias PixelBufferProvider = @Sendable (CameraFrame) async -> CVPixelBuffer?

    private let provider: PixelBufferProvider
    private let model: VNCoreMLModel
    private let confidenceThreshold: Float

    public init(
        model: VNCoreMLModel,
        provider: @escaping PixelBufferProvider,
        confidenceThreshold: Float = 0.5
    ) {
        self.provider = provider
        self.model = model
        self.confidenceThreshold = confidenceThreshold
    }

    public static func loadModel(named name: String, bundle: Bundle = .main) throws -> VNCoreMLModel {
        guard let url = bundle.url(forResource: name, withExtension: "mlmodelc") else {
            throw NSError(
                domain: "OkiMissionPlatformKit",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Compiled model \(name).mlmodelc not found in bundle"]
            )
        }
        let mlModel = try MLModel(contentsOf: url)
        return try VNCoreMLModel(for: mlModel)
    }

    public func detect(_ frame: CameraFrame, allowedClasses: Set<String>?) async throws -> [ObjectObservation] {
        guard let pixelBuffer = await provider(frame) else { return [] }
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFit
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try handler.perform([request])
        guard let observations = request.results as? [VNRecognizedObjectObservation] else { return [] }
        return observations.compactMap { obs -> ObjectObservation? in
            guard let best = obs.labels.first, best.confidence >= confidenceThreshold else { return nil }
            if let allowedClasses, !allowedClasses.contains(best.identifier) { return nil }
            let box = UnitRect(
                x: Double(obs.boundingBox.origin.x),
                y: Double(obs.boundingBox.origin.y),
                width: Double(obs.boundingBox.size.width),
                height: Double(obs.boundingBox.size.height)
            )
            return ObjectObservation(
                className: best.identifier,
                confidence: Double(best.confidence),
                boundingBox: box,
                frameId: frame.identifier
            )
        }
    }
}
#endif
