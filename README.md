# OkiMission

iOS 26 alarm app inspired by Wayk. Wakes you up, then makes you complete a
mission (pushups / squats / math / object hunt / barcode / shake) before the
alarm fully dismisses.

The repo currently houses the platform-agnostic core as a Swift Package.
The iOS App target itself is added in Xcode on macOS — see
[`docs/ios-app-target-setup.md`](docs/ios-app-target-setup.md) for the one-time
setup steps.

## Modules

| Module | Purpose |
|---|---|
| `OkiMissionCore` | Value types only: domain primitives, parameter codecs, streak math, JSONValue, motion samples. No platform imports. |
| `OkiMissionEngine` | Pure logic: PoseSmoother (EMA), PushupRepCounter, AntiCheatEvaluator, AngleMath, MathProblemGenerator (seeded), AlarmFireResolver, ShakeDetector, MissionState + MissionStateMachine. |
| `OkiMissionDomain` | SwiftData layer: entities (Alarm/MissionTemplate/MissionRun/Profile), SchemaV1, ModelContainerFactory, repositories (`@ModelActor` actors). Includes sample fixtures for previews. |
| `OkiMissionServices` | Protocols + in-memory fakes for the app's outer boundaries: AlarmServicing, AuthServicing, EntitlementServicing, MissionGenerating, AnalyticsTracking. HTTPClient layer with retry, GeminiProxyClient. Sensing protocols (camera, pose, object, motion, barcode) with scripted stubs. |
| `OkiMissionDesignSystem` | SwiftUI design tokens: AppColor / AppFont / AppSpacing / AppCornerRadius / AppAnimation. AppGlass modifier (Material-backed, ready for iOS 26 Liquid Glass swap). AppCard, AppPrimaryButtonStyle, AppSecondaryButtonStyle, AppHaptics. |

## Build & test

Requires Swift 6 toolchain. From repo root:

```sh
swift build
swift test
```

Tests use the Swift Testing framework. Test suites cover:

- `WeekdayMaskTests`, `AlarmSpecTests`, `StreakCalculatorTests`,
  `MissionParametersTests`
- `PoseSmootherTests`, `PushupRepCounterTests`, `AntiCheatEvaluatorTests`,
  `AngleMathTests`, `MathProblemGeneratorTests`, `AlarmFireResolverTests`,
  `MissionStateMachineTests`, `ShakeDetectorTests`
- `InMemoryAlarmServiceTests`, `InMemoryAuthServiceTests`,
  `InMemoryEntitlementServiceTests`, `StubMissionGeneratorTests`,
  `InMemoryAnalyticsTrackerTests`, `RetryingHTTPClientTests`,
  `GeminiProxyClientTests`

## Documentation

- `docs/ios-app-target-setup.md` — Xcode project creation and SPM linking
- `~/.claude/plans/okimission-wayk-ios-iterative-mist.md` — full product /
  technical design (not in repo)

## Roadmap

1. **Phase 1 (current)** — platform-agnostic core: value types, engine,
   SwiftData, service protocols + fakes, design tokens.
2. **Phase 2** — iOS App target, AlarmKit live adapter, Live Activity,
   BGTasks (requires Xcode 26 / iOS 26 SDK).
3. **Phase 3** — Mission UI flows (camera, pose, object hunt) + Vision
   adapters that conform to the existing `PoseDetecting` /
   `ObjectDetecting` protocols.
4. **Phase 4** — Supabase Edge Functions, RLS, Gemini live integration.
5. **Phase 5** — StoreKit / RevenueCat, paywall, 特商法.
6. **Phase 6** — Beta (TestFlight), App Store submission.
