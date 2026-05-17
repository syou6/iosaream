import Foundation
import OkiMissionServices

#if canImport(Vision) && canImport(CoreVideo)
import Vision
import CoreVideo

public actor VisionBarcodeScanner: BarcodeScanning {
    public typealias PixelBufferProvider = @Sendable (CameraFrame) async -> CVPixelBuffer?

    private let provider: PixelBufferProvider
    private let symbologies: [VNBarcodeSymbology]

    public init(
        provider: @escaping PixelBufferProvider,
        symbologies: [VNBarcodeSymbology] = [.qr, .ean13, .ean8, .code128]
    ) {
        self.provider = provider
        self.symbologies = symbologies
    }

    public func scan(_ frame: CameraFrame) async throws -> [BarcodeObservation] {
        guard let pixelBuffer = await provider(frame) else { return [] }
        let request = VNDetectBarcodesRequest()
        request.symbologies = symbologies
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try handler.perform([request])
        guard let observations = request.results as? [VNBarcodeObservation] else { return [] }
        return observations.compactMap { obs in
            guard let payload = obs.payloadStringValue else { return nil }
            let box = UnitRect(
                x: Double(obs.boundingBox.origin.x),
                y: Double(obs.boundingBox.origin.y),
                width: Double(obs.boundingBox.size.width),
                height: Double(obs.boundingBox.size.height)
            )
            return BarcodeObservation(
                payload: payload,
                symbology: obs.symbology.rawValue,
                boundingBox: box,
                frameId: frame.identifier
            )
        }
    }
}
#endif
