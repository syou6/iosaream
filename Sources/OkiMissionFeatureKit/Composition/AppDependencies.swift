import Foundation
import OkiMissionCore
import OkiMissionServices

#if canImport(SwiftUI)
import SwiftUI

@MainActor
@Observable
public final class AppDependencies {
    public var alarmService: any AlarmServicing
    public var authService: any AuthServicing
    public var entitlementService: any EntitlementServicing
    public var analytics: any AnalyticsTracking
    public var missionGenerator: any MissionGenerating
    public var runUploader: MissionRunUploader?
    public var profileSync: (any RemoteProfileSyncing)?

    public init(
        alarmService: any AlarmServicing,
        authService: any AuthServicing,
        entitlementService: any EntitlementServicing,
        analytics: any AnalyticsTracking,
        missionGenerator: any MissionGenerating,
        runUploader: MissionRunUploader? = nil,
        profileSync: (any RemoteProfileSyncing)? = nil
    ) {
        self.alarmService = alarmService
        self.authService = authService
        self.entitlementService = entitlementService
        self.analytics = analytics
        self.missionGenerator = missionGenerator
        self.runUploader = runUploader
        self.profileSync = profileSync
    }

    public static func previewStub() -> AppDependencies {
        AppDependencies(
            alarmService: InMemoryAlarmService(initialAuthorization: .authorized),
            authService: InMemoryAuthService(),
            entitlementService: InMemoryEntitlementService(),
            analytics: InMemoryAnalyticsTracker(),
            missionGenerator: StubMissionGenerator()
        )
    }
}
#endif
