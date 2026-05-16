# iOS App Target Setup

This repo currently contains the platform-agnostic core of OkiMission as a
Swift Package. The iOS App target (the actual `.xcodeproj` and `App.swift`)
needs to be created in Xcode on macOS — Linux cannot generate signed app
bundles or provision entitlements. Follow these steps once on a Mac with
Xcode 26 (or the latest available beta).

## 1. Create the App target

1. Open Xcode → `File` → `New` → `Project…`
2. Choose **iOS → App**
3. Settings:
   - Product Name: `OkiMission`
   - Team: your Apple Developer team
   - Organization Identifier: `com.yourdomain` (becomes bundle id
     `com.yourdomain.OkiMission`)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData** (this generates the @Model template — delete
     it; we use our own `OkiMissionDomain`)
   - Include Tests: ✅
4. Save the project at the repo root so the layout is:

```
/iosaream/
  OkiMission.xcodeproj/
  OkiMission/                # app sources (created by Xcode)
  OkiMissionTests/
  OkiMissionUITests/
  Package.swift              # existing SPM packages
  Sources/                   # existing
  Tests/                     # existing
```

## 2. Link the local Swift Package

In the Xcode project navigator:

1. Select the `OkiMission` project node
2. Click `+` under `Frameworks, Libraries, and Embedded Content`
3. Choose `Add Other… → Add Package Dependency…`
4. `Add Local…` and select the repo root (the folder with `Package.swift`)
5. Add the libraries you need to the App target:
   - `OkiMissionCore`
   - `OkiMissionEngine`
   - `OkiMissionDomain`
   - `OkiMissionServices`
   - `OkiMissionDesignSystem`

## 3. Capabilities and entitlements

In Signing & Capabilities for the App target, add:

- **Sign in with Apple**
- **Background Modes**:
  - Audio, AirPlay, and Picture in Picture
  - Background processing
  - Remote notifications
- **Push Notifications** (for time-sensitive nudges)
- **iCloud → CloudKit** (only when enabling Phase 2 sync)

AlarmKit-specific entitlement (likely `com.apple.developer.alarmkit`) will
appear when you `import AlarmKit` and try to call `AlarmManager` — Xcode
26 should offer to add it automatically. If not, request it via Apple
Developer Portal.

## 4. Info.plist additions

Required usage descriptions:

```xml
<key>NSCameraUsageDescription</key>
<string>Your camera is used to verify pushups, squats, and object hunt missions.</string>
<key>NSMotionUsageDescription</key>
<string>Motion data is used to verify shake-the-phone missions.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Audio feedback during missions.</string>
```

Background task identifiers:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>com.yourdomain.OkiMission.ai-prefetch</string>
  <string>com.yourdomain.OkiMission.analytics-flush</string>
</array>
```

Privacy Manifest (`PrivacyInfo.xcprivacy`) — generate via Xcode → File →
New → File → Privacy Manifest. Required reasons should follow the design
in the plan §18.2.

## 5. Wire up the App entry point

Replace the generated `OkiMissionApp.swift` with something like:

```swift
import SwiftUI
import OkiMissionCore
import OkiMissionDomain
import OkiMissionServices

@main
struct OkiMissionApp: App {
    @State private var alarmService: any AlarmServicing = InMemoryAlarmService(initialAuthorization: .notDetermined)
    @State private var authService: any AuthServicing = InMemoryAuthService()
    @State private var entitlementService: any EntitlementServicing = InMemoryEntitlementService()
    @State private var analytics: any AnalyticsTracking = InMemoryAnalyticsTracker()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.alarmService, alarmService)
                .environment(\.authService, authService)
                .environment(\.entitlementService, entitlementService)
                .environment(\.analytics, analytics)
        }
        .modelContainer(try! ModelContainerFactory.live())
    }
}
```

These start as in-memory stubs so you can build and run before the
AlarmKit / Supabase / RevenueCat live implementations land. Swap each
service for its live counterpart as the corresponding integration is
completed.

## 6. Environment keys

Add `EnvironmentValues` extensions for each service:

```swift
import SwiftUI
import OkiMissionServices

private struct AlarmServiceKey: EnvironmentKey {
    static let defaultValue: any AlarmServicing = InMemoryAlarmService()
}

extension EnvironmentValues {
    var alarmService: any AlarmServicing {
        get { self[AlarmServiceKey.self] }
        set { self[AlarmServiceKey.self] = newValue }
    }
}
```

Repeat for `authService`, `entitlementService`, `analytics`.

## 7. Verify the build

1. Select the `OkiMission` scheme + an iPhone 15 simulator
2. `Cmd-B` to build
3. `Cmd-U` to run tests (both App tests and Package tests)
4. The Package tests can also be run from the command line:

```sh
swift test
```

assuming a Swift 6 toolchain is on PATH.

## 8. Configure Xcode Cloud

Once the App target builds locally, in App Store Connect → Xcode Cloud:

1. Create a new workflow: **PR Check** (Debug, run tests on PRs)
2. Create **Beta Build** (Beta config, TestFlight internal upload)
3. Add `ci_post_clone.sh` and `ci_post_xcodebuild.sh` to `ci_scripts/`
   following the patterns in the plan §F.1.2 / §F.1.3
