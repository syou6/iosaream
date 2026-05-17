# OkiMission Architecture

This document describes the module layout and the data flow through the
repository.  All five Swift modules plus the Supabase backend live in this
repo; the iOS App target itself is created in Xcode on macOS (see
`docs/ios-app-target-setup.md`).

## Module map

```
                +-----------------------+
                |     OkiMissionCore    |   value types only, no I/O
                +-----------------------+
                            ^
       +--------------------+--------------------+
       |                    |                    |
+-------------+   +-------------------+   +--------------------+
| MissionEngine| | MissionDomain     |   | MissionServices    |
| (pure logic) | | (SwiftData)       |   | (I/O protocols +   |
|              | |                   |   |  in-memory fakes,  |
|              | |                   |   |  HTTP + Supabase)  |
+-------------+   +-------------------+   +--------------------+
       ^
       |
+-----------------------+
| OkiMissionDesignSystem|   SwiftUI tokens
+-----------------------+
```

- `OkiMissionCore` has no internal dependencies.
- `OkiMissionEngine`, `OkiMissionDomain`, and `OkiMissionServices` each
  depend on `OkiMissionCore` only.
- `OkiMissionDesignSystem` is standalone (UI tokens).
- The iOS App target (created in Xcode) will depend on all five modules.

Cross-module dependencies between Engine / Domain / Services are avoided by
passing closures: e.g. `MissionRunUploader` does not import `OkiMissionDomain`,
it accepts a `fetchUnsynced` closure that the App layer wires to
`MissionRunRepository.unsynced()`.

## Data flow

```
+----------------+   schedule(spec)   +-------------------+
| AlarmEditor UI |  ----------------> | AlarmServicing    |
+----------------+                    | (live = AlarmKit) |
                                      +-------------------+
                                                |
                                                v
+------------+   secondary intent      +----------------+
| AlarmKit   |  --------------------> | StartMissionIntent
| (system)   |                         | -> deep link
+------------+                         +----------------+
                                                |
                                                v
+------------------+   start             +----------------------+
| MissionExperience|  <-----------------|  Mission UI (SwiftUI) |
| (actor in Engine)|   feed sensor data |                       |
+------------------+   ---------------> +----------------------+
       |                                          ^
       | finalRecord                              |
       v                                          |
+---------------------+    persist     +-----------------------+
| MissionRunRecord    | -------------> | MissionRunRepository  |
+---------------------+                | (SwiftData)           |
                                       +-----------------------+
                                                |
                                                v
+----------------------+    upload     +-----------------------+
| MissionRunUploader   | <-----------  | SupabaseRunSyncClient |
| (actor in Services)  |               | (HTTPClient + REST)   |
+----------------------+               +-----------------------+
                                                |
                                                v
                                       +-----------------------+
                                       | Supabase mission_runs |
                                       +-----------------------+
```

The Edge Functions side mirrors this:

```
iOS app ---POST--> /functions/v1/missions-generate  ---> Gemini 2.5 Flash
                                                          |
                                                          v
                                                 mission_generations cache
                                                          |
                                                          v
                                                  iOS app (template)

RevenueCat ---POST--> /functions/v1/billing-webhook
                          |
                          v
                  profiles.subscription_tier

iOS app ---POST--> /functions/v1/account-delete
                          |
                          v
                  soft_delete_account RPC
                          |
                          v
                  apple_revoke_queue
```

## State machine

`MissionStateMachine` is a pure Sendable struct.  Transitions are explicit
methods and the state is observable to the App layer through
`MissionExperience.events`:

```
idle
  | start()
  v
checkingCapabilities
  | capabilityResolved(authorized: true)
  v
framing(progress)                <-- N sustained over-threshold frames
  | updateFraming(progress: ...)
  v
running(progress)
  | updateProgress() | reportPoseAngle | submitMathAnswer | ...
  | conditionsMet() (when engine.isComplete)
  v
verifying
  | verified(clean: true)        verified(clean: false, signals: [...])
  v                                v
completed                       cheated([...])

(any non-terminal state can transition to: paused -> running, cancelled, failed)
```

## Anti-cheat scoring

`AntiCheatEvaluator` scores an `AntiCheatContext` against a configurable
policy.  Signals contribute the following weights:

| Signal | Weight |
|---|---|
| backgrounded(count: n) | 2 * n |
| clockTampered | 5 |
| screenshotsTaken(count: n) | n |
| frameGaps (3+ gaps > 1.0s) | 3 |
| tooFast (duration < kind minimum) | 4 |

The verdict is `.cheated(signals)` if the total reaches `failingScore`
(default 5).  Each `MissionRunRecord` carries the signal list so the App
layer can show appropriate UX (warning banner, streak skip, etc.).

## Subscription state

```
EntitlementServicing
  - live = RevenueCat (Phase 2)
  - stub = InMemoryEntitlementService (Phase 1)
   |
   v  customerInfo stream
  EntitlementStore  --(profile.subscription_tier)--> server cache
                       (via RC webhook + billing-webhook function)
```

The client treats `EntitlementServicing.currentEntitlement` as the
authoritative source for feature gating; the server-side cache is for
offline display and cross-device sync only.

## Tests

Each pure module has its own test target.  Service tests use the in-memory
fakes and `StubHTTPClient`; engine tests use scripted detectors,
`StubClock`, and `SeededRandom` for determinism.  See
`Tests/OkiMissionEngineTests/MissionExperienceTests.swift` for an end-to-end
example exercising the state machine, per-kind engine, and anti-cheat
evaluator together.

## Deferred / external

The following pieces are intentionally not in this repo and require Xcode
or external accounts:

- iOS App target (`.xcodeproj`) + SwiftUI screens
- AlarmKit live adapter implementing `AlarmServicing`
- AVCaptureSession / Vision adapters implementing `CameraSessioning`,
  `PoseDetecting`, `ObjectDetecting`, `BarcodeScanning`
- CoreMotion adapter implementing `MotionSensing`
- RevenueCat SDK wiring implementing `EntitlementServicing`
- Sign in with Apple adapter implementing `AuthServicing`
- Sentry / PostHog SDK wiring implementing `AnalyticsTracking` and crash
  reporting
- Supabase project setup, secret management, Edge Function deployment
- LP / Privacy Policy / 特商法 HTML pages (generated from
  `docs/legal/*.md`)
