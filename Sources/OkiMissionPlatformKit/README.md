# OkiMissionPlatformKit

iOS-specific live adapters that conform to the protocols in
`OkiMissionServices`. Every adapter file is wrapped in
`#if canImport(<Framework>)` so the package still resolves on platforms
without the underlying framework (Linux, server-side Swift).

## Adapters included

| File | Conforms to | Backing framework |
|---|---|---|
| `Vision/VisionPoseDetector.swift` | `PoseDetecting` | Vision (`VNDetectHumanBodyPoseRequest`) |
| `Vision/VisionBarcodeScanner.swift` | `BarcodeScanning` | Vision (`VNDetectBarcodesRequest`) |
| `Vision/VisionObjectDetector.swift` | `ObjectDetecting` | Vision + CoreML (`VNCoreMLRequest`) |
| `Camera/AVCaptureCameraSession.swift` | `CameraSessioning` | AVFoundation |
| `Motion/CoreMotionSensor.swift` | `MotionSensing` | CoreMotion |
| `AlarmKit/AlarmKitAdapter.swift` | `AlarmServicing` | AlarmKit (iOS 26) |
| `Subscriptions/RevenueCatEntitlementService.swift` | `EntitlementServicing` | RevenueCat SDK |
| `Auth/SupabaseAuthService.swift` | `AuthServicing` | supabase-swift |
| `Analytics/PostHogAnalyticsTracker.swift` | `AnalyticsTracking` | PostHog iOS SDK |

## Status caveats

- **AlarmKit**: API names are based on the WWDC 2025 preview and may
  change before the public release. Symbols to re-verify against the
  Xcode 26 GM SDK are listed at the top of `AlarmKitAdapter.swift`.
- **VisionObjectDetector**: requires a trained CoreML model bundled
  with the app (`.mlmodelc`). See `MissionEngine` plan §B.4 for
  dataset acquisition guidance.
- **RevenueCat / supabase-swift / PostHog**: not declared as SPM
  dependencies in `Package.swift` because they are external SDKs.
  Add them to the App target's Package Dependencies in Xcode, then
  the matching adapter file compiles automatically thanks to the
  `#if canImport` guard.

## Wiring camera frames to detectors

`AVCaptureCameraSession` accepts a `pixelBufferHandler` closure so the
App layer can route the `CVPixelBuffer` to whichever detector(s) are
active for the current mission kind. Typical wiring:

```swift
let session = AVCaptureCameraSession { frame, pixelBuffer in
    Task { [weak self] in
        guard let self else { return }
        switch self.currentMission.kind {
        case .pushup, .squat:
            if let obs = try? await self.poseDetector.detect(frame) {
                await self.experience.reportPoseAngle(...)
            }
        case .objectHunt:
            if let observations = try? await self.objectDetector.detect(frame, allowedClasses: ...) {
                await self.experience.reportDetectedClasses(Set(observations.map(\.className)))
            }
        case .barcode:
            if let observations = try? await self.barcodeScanner.scan(frame) {
                for obs in observations { await self.experience.reportBarcode(obs.payload) }
            }
        default: break
        }
    }
}
```

The detector protocols are designed so each takes a `CameraFrame`
(value-type id + dimensions) and the live impls keep the heavy
`CVPixelBuffer` out of the `Sendable` API surface.
