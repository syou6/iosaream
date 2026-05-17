// Drop this file into the iOS App target in Xcode as OkiMissionApp.swift.
// It is provided as a snippet rather than a compiled source file because
// the App target itself is created in Xcode (it cannot live inside the
// Swift Package).

import SwiftUI
import SwiftData
import OkiMissionCore
import OkiMissionDomain
import OkiMissionServices
import OkiMissionPlatformKit
import OkiMissionFeatureKit

@main
struct OkiMissionApp: App {
    @State private var dependencies: AppDependencies
    @State private var modelContainer: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainerFactory.live()
        } catch {
            fatalError("failed to create model container: \(error)")
        }
        _modelContainer = State(initialValue: container)
        _dependencies = State(initialValue: OkiMissionApp.makeDependencies(container: container))
        OkiMissionApp.bootstrapBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appDependencies, dependencies)
                .modelContainer(modelContainer)
                .task { await bootstrap() }
        }
    }

    private func bootstrap() async {
        // Bridge alarm intents (Stop / StartMission) to in-app routing.
        await AlarmIntentBridge.shared.registerStopHandler { alarmId in
            try? await dependencies.alarmService.cancel(domainAlarmId: alarmId)
        }
        await AlarmIntentBridge.shared.registerStartHandler { alarmId in
            // route to mission UI via router here; this snippet only shows the wiring point.
            print("Mission start requested for alarm \(alarmId)")
        }

        // Request alarm authorization on first launch.
        _ = try? await dependencies.alarmService.requestAuthorization()

        // Re-sync alarms after process restart.
        if let alarmKit = dependencies.alarmService as? AlarmKitAdapter {
            await alarmKit.bootstrap()
        }
    }

    // MARK: - DI assembly

    private static func makeDependencies(container: ModelContainer) -> AppDependencies {
        let config = try! AppConfig.from(infoDictionary: Bundle.main.infoDictionary ?? [:])

        let baseHTTP = URLSessionHTTPClient()
        let httpClient: any HTTPClient = RetryingHTTPClient(inner: baseHTTP)

        // Auth ---------------------------------------------------------------
        let authService: any AuthServicing = SupabaseAuthService(
            supabaseURL: config.supabaseURL,
            supabaseAnonKey: config.supabaseAnonKey
        )

        // Entitlement -------------------------------------------------------
        Purchases.configure(withAPIKey: config.revenueCatAPIKey)
        let entitlementService: any EntitlementServicing = RevenueCatEntitlementService()

        // Analytics ---------------------------------------------------------
        let analytics: any AnalyticsTracking = {
            if let key = config.posthogAPIKey {
                return PostHogAnalyticsTracker(apiKey: key, host: config.posthogHost)
            }
            return InMemoryAnalyticsTracker()
        }()

        // Mission generator -------------------------------------------------
        let geminiClient = GeminiProxyClient(
            httpClient: httpClient,
            configuration: GeminiProxyConfiguration(baseURL: config.supabaseURL, anonKey: config.supabaseAnonKey),
            tokenProvider: { [authService] in
                if let session = await authService.currentSession {
                    return session.accessToken
                }
                throw AuthError.notAuthenticated
            }
        )
        let missionGenerator: any MissionGenerating = MissionGenerationOrchestrator(
            primary: geminiClient,
            fallback: StubMissionGenerator()
        )

        // Run uploader ------------------------------------------------------
        let runSync = SupabaseRunSyncClient(
            httpClient: httpClient,
            configuration: SupabaseConfiguration(baseURL: config.supabaseURL, anonKey: config.supabaseAnonKey),
            userIdProvider: { [authService] in
                if let session = await authService.currentSession {
                    return session.userId
                }
                throw RemoteRunSyncError.unauthorized
            },
            tokenProvider: { [authService] in
                if let session = await authService.currentSession {
                    return session.accessToken
                }
                throw RemoteRunSyncError.unauthorized
            }
        )
        let runUploader = MissionRunUploader(
            syncing: runSync,
            fetchUnsynced: {
                let repo = MissionRunRepository(modelContainer: container)
                let entities = try await repo.unsynced()
                return entities.map(MissionRunRecord.init(entity:))
            },
            markSynced: { ids in
                let repo = MissionRunRepository(modelContainer: container)
                try await repo.markSynced(ids: ids)
            }
        )

        // AlarmKit ---------------------------------------------------------
        let alarmService: any AlarmServicing = AlarmKitAdapter(
            stopIntentFactory: { alarmId in StopAlarmIntent(alarmId: alarmId) },
            secondaryIntentFactory: { alarmId in StartMissionIntent(alarmId: alarmId) }
        )

        return AppDependencies(
            alarmService: alarmService,
            authService: authService,
            entitlementService: entitlementService,
            analytics: analytics,
            missionGenerator: missionGenerator,
            runUploader: runUploader,
            profileSync: nil
        )
    }

    private static func bootstrapBackgroundTasks() {
        let coordinator = BackgroundTaskCoordinator()
        coordinator.registerRunSync { task in
            BackgroundJobRunner.runWithExpiration(task) {
                // Resolve the App-level uploader via your DI of choice.
                // (Skipped here; this snippet shows the registration shape.)
                return true
            }
        }
        coordinator.registerAIPrefetch { task in
            BackgroundJobRunner.runWithExpiration(task) {
                return true
            }
        }
        coordinator.scheduleRunSync(earliestBeginDate: Date(timeIntervalSinceNow: 60 * 30))
    }
}
