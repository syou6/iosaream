# OkiMission

iOS 26 alarm app inspired by Wayk. Wakes you up, then makes you complete a
mission (pushups / squats / math / object hunt / barcode / shake) before the
alarm fully dismisses.

The repo currently houses the platform-agnostic core, the iOS-specific
adapters, and the SwiftUI feature layer as a Swift Package. The iOS App
target itself (the `.xcodeproj` + `@main App`) is added in Xcode on
macOS using the snippet at `docs/snippets/OkiMissionApp.swift`; see
[`docs/ios-app-target-setup.md`](docs/ios-app-target-setup.md) for the
one-time setup walkthrough.

## Modules

| Module | Purpose |
|---|---|
| `OkiMissionCore` | Value types only. Domain primitives (`MissionKind`, `AlarmSpec`, `Difficulty`, `WeekdayMask`), parameter codecs, `StreakCalculator`, `JSONValue`, `MissionRunRecord`, `GeneratedMissionTemplate`, `AccelerationSample`, `AppClock`. No platform imports. |
| `OkiMissionEngine` | Pure logic. `PoseSmoother`, `PushupRepCounter`, `AntiCheatEvaluator`, `AngleMath`, `MathProblemGenerator` (seeded), `AlarmFireResolver`, `ShakeDetector`, `MissionState` + `MissionStateMachine`, per-kind engines (Math / Pushup / Squat / Shake / ObjectHunt / Barcode), and the `MissionExperience` orchestrator actor with `finalRecord(...)`. |
| `OkiMissionDomain` | SwiftData layer. Entities (`AlarmEntity`, `MissionTemplateEntity`, `MissionRunEntity`, `ProfileEntity`), `SchemaV1`, `ModelContainerFactory`, `@ModelActor` repositories (Alarm / MissionRun / Profile), and `Entity <-> Record` mappings. Sample fixtures for previews. |
| `OkiMissionServices` | Protocols + in-memory fakes for the outer boundaries: `AlarmServicing`, `AuthServicing`, `EntitlementServicing`, `MissionGenerating` + `MissionGenerationOrchestrator`, `AnalyticsTracking`, `CameraSessioning`, `PoseDetecting`, `ObjectDetecting`, `MotionSensing`, `BarcodeScanning`. `HTTPClient` with `RetryingHTTPClient`. `GeminiProxyClient`, `SupabaseRunSyncClient`, `SupabaseProfileSyncClient`. `MissionRunUploader`. `AppConfig`. |
| `OkiMissionDesignSystem` | SwiftUI tokens. `AppColor` (UIKit / AppKit / fallback), `AppFont`, `AppSpacing`, `AppCornerRadius`, `AppAnimation` (`accessibilityReduceMotion`-aware), `AppGlass` modifier (Material-backed, swap to Liquid Glass when finalised), `AppCard`, `AppPrimaryButtonStyle`, `AppSecondaryButtonStyle`, `AppHaptics`. |
| `OkiMissionPlatformKit` | iOS-only live adapters gated by `#if canImport(<Framework>)`: `VisionPoseDetector`, `VisionBarcodeScanner`, `VisionObjectDetector`, `AVCaptureCameraSession`, `CoreMotionSensor`, `AlarmKitAdapter`, `RevenueCatEntitlementService`, `SupabaseAuthService`, `PostHogAnalyticsTracker`. Plus `StopAlarmIntent` / `StartMissionIntent` (App Intents), `BackgroundTaskCoordinator`, `MissionRunRecorder`. |
| `OkiMissionFeatureKit` | SwiftUI navigation, composition root, and feature screens. `Router` (`@Observable @MainActor`), `AppRoute`, `AppDependencies`, `EnvironmentValues` extensions, `RootView` (TabView shell), `AlarmListView`, `AlarmEditorView`, `MissionShellView` + per-kind subviews, `PaywallView`, `SettingsView`, `OnboardingView`. |

## Backend

```
supabase/
  config.toml                    Supabase CLI configuration
  migrations/                    SQL: schema / indexes / RLS / functions / triggers / cron
  functions/
    _shared/                     auth / cors / errors / rate_limit helpers
    missions-generate/           Gemini 2.5 Flash structured-output endpoint
    billing-webhook/             RevenueCat HMAC-verified webhook
    account-delete/              Soft delete + auth user removal + Apple revoke queue
    push-send/                   Internal-only ES256 APNs sender
```

## Documentation

- `docs/architecture.md` — module map, data flow, state machine, anti-cheat scoring.
- `docs/startup-checklist.md` — week-by-week setup plan from clone to App Store submission.
- `docs/ios-app-target-setup.md` — one-time Xcode project creation, SPM linking, capabilities.
- `docs/snippets/OkiMissionApp.swift` — `@main App` composition root reference.
- `docs/PrivacyInfo.xcprivacy` — drop-in Privacy Manifest.
- `docs/legal/*.md` — Japanese privacy policy / terms / 特商法 drafts.

## Build & test

```sh
swift build
swift test
```

Requires Swift 6 / Xcode 26. Tests use the Swift Testing framework
(`import Testing`).

## Roadmap

1. **Phase 0–7 (done)** — platform-agnostic core, SwiftData persistence,
   service protocols + in-memory fakes, HTTP + Gemini + Supabase clients,
   MissionExperience orchestrator with run sync.
2. **Phase 8–11 (done)** — backend (SQL + Edge Functions), iOS live
   adapters (Vision / AVCapture / CoreMotion / AlarmKit / RevenueCat /
   PostHog / Supabase auth), SwiftUI feature kit.
3. **Phase 12 (next, requires Xcode + Mac)** — create the App target
   from `docs/ios-app-target-setup.md`, wire in
   `docs/snippets/OkiMissionApp.swift`, validate against a simulator.
4. **Phase 13** — flesh out missing screens, add SwiftUI snapshot tests.
5. **Phase 14** — deploy Supabase backend, configure RevenueCat
   webhook, deploy LP / legal pages.
6. **Phase 15** — TestFlight beta, App Store submission.
