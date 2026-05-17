import Foundation
import OkiMissionServices

#if canImport(AVFoundation) && canImport(CoreVideo) && os(iOS)
import AVFoundation
import CoreVideo

public final class AVCaptureCameraSession: NSObject, CameraSessioning, @unchecked Sendable {
    public typealias PixelBufferHandler = @Sendable (CameraFrame, CVPixelBuffer) -> Void

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.okimission.camera", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private let continuation: AsyncStream<CameraFrame>.Continuation
    public let frames: AsyncStream<CameraFrame>
    private let pixelBufferHandler: PixelBufferHandler?
    private var configured = false

    public init(pixelBufferHandler: PixelBufferHandler? = nil) {
        let (stream, continuation) = AsyncStream.makeStream(of: CameraFrame.self)
        self.frames = stream
        self.continuation = continuation
        self.pixelBufferHandler = pixelBufferHandler
        super.init()
    }

    public func start() async throws {
        try configureIfNeeded()
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { throw CameraError.unauthorized }
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraError.unauthorized
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                self?.session.startRunning()
                cont.resume()
            }
        }
    }

    public func stop() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                self?.session.stopRunning()
                cont.resume()
            }
        }
        continuation.finish()
    }

    private func configureIfNeeded() throws {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video) else {
            session.commitConfiguration()
            throw CameraError.unavailable
        }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            session.commitConfiguration()
            throw CameraError.configurationFailed("device input: \(error.localizedDescription)")
        }
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.configurationFailed("cannot add input")
        }
        session.addInput(input)

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw CameraError.configurationFailed("cannot add output")
        }
        session.addOutput(output)
        session.commitConfiguration()
        configured = true
    }
}

extension AVCaptureCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let frame = CameraFrame(timestamp: timestamp, width: width, height: height)
        pixelBufferHandler?(frame, pixelBuffer)
        continuation.yield(frame)
    }
}
#endif
