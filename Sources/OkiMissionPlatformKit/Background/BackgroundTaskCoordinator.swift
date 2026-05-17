import Foundation

#if canImport(BackgroundTasks) && os(iOS)
import BackgroundTasks

public enum BackgroundTaskIdentifier {
    public static let aiPrefetch = "com.example.OkiMission.ai-prefetch"
    public static let analyticsFlush = "com.example.OkiMission.analytics-flush"
    public static let runSync = "com.example.OkiMission.run-sync"
}

public final class BackgroundTaskCoordinator: @unchecked Sendable {
    public typealias TaskHandler = @Sendable (BGTask) -> Void

    private let scheduler: BGTaskScheduler

    public init(scheduler: BGTaskScheduler = .shared) {
        self.scheduler = scheduler
    }

    public func registerAIPrefetch(_ handler: @escaping TaskHandler) {
        scheduler.register(
            forTaskWithIdentifier: BackgroundTaskIdentifier.aiPrefetch,
            using: nil,
            launchHandler: handler
        )
    }

    public func registerAnalyticsFlush(_ handler: @escaping TaskHandler) {
        scheduler.register(
            forTaskWithIdentifier: BackgroundTaskIdentifier.analyticsFlush,
            using: nil,
            launchHandler: handler
        )
    }

    public func registerRunSync(_ handler: @escaping TaskHandler) {
        scheduler.register(
            forTaskWithIdentifier: BackgroundTaskIdentifier.runSync,
            using: nil,
            launchHandler: handler
        )
    }

    public func scheduleAIPrefetch(earliestBeginDate: Date) {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskIdentifier.aiPrefetch)
        request.earliestBeginDate = earliestBeginDate
        try? scheduler.submit(request)
    }

    public func scheduleAnalyticsFlush(earliestBeginDate: Date) {
        let request = BGProcessingTaskRequest(identifier: BackgroundTaskIdentifier.analyticsFlush)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = earliestBeginDate
        try? scheduler.submit(request)
    }

    public func scheduleRunSync(earliestBeginDate: Date) {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskIdentifier.runSync)
        request.earliestBeginDate = earliestBeginDate
        try? scheduler.submit(request)
    }

    public func cancelAll() {
        scheduler.cancelAllTaskRequests()
    }
}

public enum BackgroundJobRunner {
    public static func runWithExpiration(
        _ task: BGTask,
        work: @escaping () async -> Bool
    ) {
        let workTask = Task {
            let success = await work()
            task.setTaskCompleted(success: success)
        }
        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
#endif
