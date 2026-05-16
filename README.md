# OkiMission

iOS 26 alarm app inspired by Wayk. Wakes you up, then makes you complete a mission
(pushups / squats / math / object hunt / barcode scan / shake) before the alarm
fully dismisses.

## Phase 0 — Pure logic foundation

This repo currently contains the platform-agnostic core of the app: pure Swift
domain types and the mission engine logic. No iOS frameworks are required to
build or test these modules. The iOS app target, AlarmKit integration, SwiftData
schema, and SwiftUI views will be added in subsequent phases.

## Modules

- `OkiMissionCore` — value types (MissionKind, Difficulty, Weekday, TimeOfDay,
  AlarmScheduleKind, MissionOutcome, AntiCheatSignal, DomainError, Capability,
  Clock).
- `OkiMissionEngine` — pure mission logic: `PoseSmoother` (EMA filter),
  `PushupRepCounter` (state machine for pushup counting), `AntiCheatEvaluator`
  (scoring of suspicious signals), `AngleMath`.

## Build & test

Requires Swift 6 toolchain. From repo root:

```sh
swift build
swift test
```

Tests use the Swift Testing framework (`import Testing`).

## Roadmap

Detailed design lives in `~/.claude/plans/okimission-wayk-ios-iterative-mist.md`.

Next phases:

1. **Phase 1** — Xcode project, App target, SwiftUI shell, DesignSystem package,
   SwiftData schema v1.
2. **Phase 2** — AlarmKit service layer, Live Activity, BGTasks (requires
   Xcode 26 / iOS 26 SDK).
3. **Phase 3** — Mission UIs (camera, pose, object hunt), Vision integration.
4. **Phase 4** — Supabase backend, Edge Functions, Gemini mission generator.
5. **Phase 5** — StoreKit / RevenueCat, paywall, 特商法.
6. **Phase 6** — Beta, App Store submission.
