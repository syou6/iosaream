import Foundation
import OkiMissionCore

// App Intents wired to AlarmKit's stop / secondary buttons. These are
// instantiated by the AlarmKitAdapter and surfaced as the system action
// when the alarm presentation is tapped. The App target observes the
// AppRouter notifications below and routes to the mission UI.

#if canImport(AppIntents) && os(iOS)
import AppIntents

public struct StopAlarmIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "アラームを停止"
    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = false

    @Parameter(title: "Alarm ID")
    public var alarmIdString: String

    public init() {
        self.alarmIdString = ""
    }

    public init(alarmId: UUID) {
        self.alarmIdString = alarmId.uuidString
    }

    public func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmIdString) {
            await AlarmIntentBridge.shared.stop(alarmId: id)
        }
        return .result()
    }
}

public struct StartMissionIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "ミッションを開始"
    public static var openAppWhenRun: Bool = true
    public static var isDiscoverable: Bool = false

    @Parameter(title: "Alarm ID")
    public var alarmIdString: String

    public init() {
        self.alarmIdString = ""
    }

    public init(alarmId: UUID) {
        self.alarmIdString = alarmId.uuidString
    }

    public func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmIdString) {
            await AlarmIntentBridge.shared.startMission(alarmId: id)
        }
        return .result()
    }
}

public actor AlarmIntentBridge {
    public static let shared = AlarmIntentBridge()

    public typealias Handler = @Sendable (UUID) async -> Void

    private var stopHandler: Handler?
    private var startHandler: Handler?

    public func registerStopHandler(_ handler: @escaping Handler) {
        stopHandler = handler
    }

    public func registerStartHandler(_ handler: @escaping Handler) {
        startHandler = handler
    }

    func stop(alarmId: UUID) async {
        await stopHandler?(alarmId)
    }

    func startMission(alarmId: UUID) async {
        await startHandler?(alarmId)
    }
}
#endif
