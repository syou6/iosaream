# OkiMissionFeatureKit

SwiftUI navigation, composition root, and feature screens. The iOS App
target depends on this module and only writes the `@main App` entry
point itself.

## Composition

```
RootView                          (TabView shell)
├ AlarmListView                   tab
├ MissionHistoryView              tab
└ SettingsView                    tab

  router.push -> NavigationStack destinations
    AlarmEditorView, ...
  router.present -> .sheet
    PaywallView, TokushohoView, OnboardingView, MissionResultView
  router.openFullScreen -> .fullScreenCover
    MissionShellView, OnboardingView
```

## Dependency injection

`AppDependencies` (an `@Observable @MainActor` class) bundles every
service the views need. Inject it through `EnvironmentValues`:

```swift
@main
struct OkiMissionApp: App {
    @State private var dependencies = AppDependencies(...)
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appDependencies, dependencies)
                .modelContainer(try! ModelContainerFactory.live())
        }
    }
}
```

Views read it with `@Environment(\.appDependencies)`. Previews can fall
back to `AppDependencies.previewStub()` which wires every protocol to
an in-memory fake.

## Router

`Router` exposes:
- `path: [AppRoute]` for `NavigationStack` navigation
- `modal: ModalRoute?` for `.sheet`
- `fullScreen: FullScreenRoute?` for `.fullScreenCover`
- `handleDeepLink(_:)` for `okimission://...` URLs

Read it via `@Environment(\.router)`. `RootView` owns the live instance
and installs it in the environment, so any child view can navigate
without prop-drilling.

## Mission UI

`MissionShellView` is the single full-screen runner for any mission
kind. It loads (or receives) a `GeneratedMissionTemplate`, instantiates
`MissionExperience`, and renders a kind-specific view inside its body:

- `MathMissionView` (full impl, demonstrates the actor consumption
  pattern)
- `PoseMissionView`, `ShakeMissionView`, `ObjectHuntMissionView`,
  `BarcodeMissionView` (placeholder shells; wire sensor adapters per
  the OkiMissionPlatformKit README)

When the underlying state machine reaches a terminal state,
`MissionShellView` calls `finalRecord(...)`, hands the
`MissionRunRecord` to `MissionResultView`, and then your
post-mission persistence + sync flow (see PlatformKit
`MissionRunRecorder`).

## Caveats

These files compile cleanly only when SwiftUI + UIKit are available
(iOS). They are gated by `#if canImport(SwiftUI)` so the package
resolves on Linux / pure-macOS Swift Testing runs.

The `AlarmEditorView` and `MissionShellView` drafts hydrate placeholder
state in their initialisers because hooking them into the real
`AlarmRepository` / template fetch requires the iOS App composition
root. Replace those stubs with `@Query` + the repository fetch when
wiring into the App target.
